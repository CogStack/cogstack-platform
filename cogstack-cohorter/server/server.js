const fs = require('fs');
const path = require("path");
const readline = require("readline");
const express = require("express");
const { Document } = require("flexsearch");

const app = express();

app.use(express.static(path.join(__dirname, '../client/public')));
app.use(express.json());
app.use(express.urlencoded({extended: false}));

// index all the snomed concepts
const snomed_terms = require('./data/snomed_terms.json');
const cui_pt2ch = require('./data/cui_pt2ch.json');

//========================================================
// db variables
const sex_code2id = {
    'Male': 1,
    'Female': 2,
    'Unknown': 3
}
const eth_code2id = {
    'Asian': 1,
    'Black': 2,
    'White': 3,
    'Mixed': 4,
    'Other': 5,
    'Unknown': 6
}
// snomed terms code2id
let cui_code2id = {};
snomed_terms.forEach((t, i)=>{ cui_code2id[t['cui']] = i });

function get_cui_child_terms(cui) {
    if (!(cui in cui_pt2ch)) return [cui];
    let s = new Set([cui]);
    for (;;) {
        let r = new Set(s);
        for (const t of r) if (t in cui_pt2ch) for (const t2 of cui_pt2ch[t]) r.add(t2);
        if (s.size == r.size) return [...s];
        else s = new Set(r);
    }
}
//========================================================

//========================================================
// flexsearch index for snomed terms
console.time('flexsearch index');
const snomed_terms_index = new Document({
    document: {
        id: "cui",
        index: ["str"]
    },
    optimize: true,
    preset: "performance",
    tokenize: "forward"
});
snomed_terms.forEach( (t, ind) => { snomed_terms_index.add(ind, t); });
console.timeEnd('flexsearch index')
//========================================================

//========================================================
// read app data
console.time('Data');
const ptt2sex = require('./data/ptt2sex.json');
const ptt2age = require('./data/ptt2age.json');
const ptt2eth = require('./data/ptt2eth.json');
const ptt2dod = require('./data/ptt2dod.json');
console.timeEnd('Data');

let i = 0;
let ptt_code2id = {};
let ptt_id2code = [];
Object.keys(ptt2age).forEach(k => {
    if (k in ptt2age && k in ptt2eth && k in ptt2eth) {
        ptt_id2code.push(k);
        ptt_code2id[k] = i;
        i++;
    }
});
const all_ptt_cnt = ptt_id2code.length;
const all_cui_cnt = snomed_terms.length;

// change all ptt to integer (id)
let ptt2sex_arr = {};
let ptt2age_arr = {};
let ptt2eth_arr = {};
let ptt2dod_arr = {};
Object.entries(ptt2sex).forEach(e => { if (e[0] in ptt_code2id) ptt2sex_arr[ptt_code2id[e[0]]] = sex_code2id[e[1]]; });
Object.entries(ptt2age).forEach(e => { if (e[0] in ptt_code2id) ptt2age_arr[ptt_code2id[e[0]]] = Math.floor(e[1]); });
Object.entries(ptt2eth).forEach(e => { if (e[0] in ptt_code2id) ptt2eth_arr[ptt_code2id[e[0]]] = eth_code2id[e[1]]; });
for (let i=0;i<all_ptt_cnt;i++) ptt2dod_arr[i] = 0;
Object.entries(ptt2dod).forEach(e => { if (e[0] in ptt_code2id) ptt2dod_arr[ptt_code2id[e[0]]] = e[1]; });
delete ptt2sex;
delete ptt2age;
delete ptt2eth;
delete ptt2dod;

let cui2ptt_arr = {};
let ptt2cui_arr = {};
let cui2ptt_tsp_arr = {};
let ptt2cui_tsp_arr = {};
for (let i=0;i<all_cui_cnt;i++) cui2ptt_arr[i] = [];
for (let i=0;i<all_ptt_cnt;i++) ptt2cui_arr[i] = [];
for (let i=0;i<all_cui_cnt;i++) cui2ptt_tsp_arr[i] = {};
for (let i=0;i<all_ptt_cnt;i++) ptt2cui_tsp_arr[i] = {};

// read mention data and build cache
(async () => {
    // cui2ptt_arr and ptt2cui_arr (all with cnt > 1)
    console.log('building cui2ptt_arr and ptt2cui_arr');
    console.time('cui2ptt_arr, ptt2cui_arr');
    const read_cui2ptt_arr = readline.createInterface({
        input: fs.createReadStream(path.join(__dirname, './data/cui2ptt_pos.jsonl'))
    });
    let lineNumber = 0;
    for await (const line of read_cui2ptt_arr){
        const obj = JSON.parse(line);
        let cui = Object.keys(obj)[0];
        Object.keys(obj[cui]).forEach(ptt => {
            if (obj[cui][ptt] > 1) {
                if (cui in cui_code2id && ptt in ptt_code2id) {
                    cui2ptt_arr[cui_code2id[cui]].push(ptt_code2id[ptt]);
                    ptt2cui_arr[ptt_code2id[ptt]].push(cui_code2id[cui]);
                }
            }
        });
        if (++lineNumber % 5000 ==0) console.log('Reading cui2ptt_pos line:', lineNumber);
    }
    console.log('Finished reading cui2ptt_arr, ptt2cui_arr');
    console.timeEnd('cui2ptt_arr, ptt2cui_arr');

    // cui2ptt_tsp
    console.time('cui2ptt_tsp');
    lineNumber = 0;
    const read_cui2ptt_tsp = readline.createInterface({
        input: fs.createReadStream(path.join(__dirname, './data/cui2ptt_tsp.jsonl'))
    });
    for await (const line of read_cui2ptt_tsp){
        const obj = JSON.parse(line);
        const cui = Object.keys(obj)[0];
        if (cui in cui_code2id) {
            const s = new Set([...cui2ptt_arr[cui_code2id[cui]]]);
            Object.keys(obj[cui]).forEach(ptt => {
                if (cui in cui_code2id && ptt in ptt_code2id && s.has(ptt_code2id[ptt])) {
                    cui2ptt_tsp_arr[cui_code2id[cui]][ptt_code2id[ptt]] = obj[cui][ptt];
                    //ptt2cui_tsp_arr[ptt_code2id[ptt]][cui_code2id[cui]] = obj[cui][ptt];
                }
            });
        }
        if (++lineNumber % 5000 ==0) console.log('Reading cui2ptt_tsp, line:', lineNumber);
    }
    console.log('Finished reading cui2ptt_tsp');
    console.timeEnd('cui2ptt_tsp');
})();
//========================================================

//========================================================
// api to handle keywords search for snomed terms
app.post("/keywords", (req, res) => {
    try {
        let text = req.body.text.replace(/\W/g, ' ').replace(/\s+/g, ' ').trim();
        let flexresult = snomed_terms_index.search(text, 500);
        flexresult = flexresult[0] ? flexresult[0].result : [];
        // rank flexresult
        let suggestions = [];
        flexresult.forEach(id => {
            let score = 0.0;
            text.split(' ').forEach( w => {
                const re = new RegExp(w, 'gi');
                if (re.exec(snomed_terms[id]['str']) != null) score += 1.0;
            });
            score += 1.0 / snomed_terms[id]['str'].length;
            suggestions.push({cui:snomed_terms[id]['cui'], str:snomed_terms[id]['str'], score: score});
        });
        suggestions.sort((a,b) => b.score - a.score);
        suggestions.forEach( suggestion => {
            let matches = new Set();
            text.split(' ').forEach( w => {
                const re = new RegExp(w, 'gi');
                let match = null;
                while ((match = re.exec(suggestion['str'])) != null) for (let pos=0;pos<w.length;pos++) matches.add(pos+match.index);
            });
            let hl = "";
            suggestion['str'].split('').forEach((c,i) => { if (matches.has(i)) hl += "<b>" + c + "</b>"; else hl += c; });
            suggestion['hl'] = hl;
        });
        res.status(200).json(suggestions).end();
    } catch (err) {
        console.log('/keywords err:', err)
        res.status(200).json([]).end();
    }
});
//========================================================

// for all users
let global_results = {};
let global_cache = {};

const seconds_in_a_year = 60*60*24*365;
let cur_time = Math.floor(Date.now() / 1000);

function age_custom_filter(constraint, age) {
    if (constraint['min'] != '' && constraint['max'] != '') return (age >= constraint['min'] && age <= constraint['max']);
    else if (constraint['min'] != '') return (age >= constraint['min']);
    else if (constraint['max'] != '') return (age <= constraint['max']);
    else return (age >= 0);
}

function time_filter(constraint, tsp) {
    let c1 = false;
    let c2 = false;
    let c3 = false;
    if (constraint['1'] == true) c1 = (tsp >= (cur_time - (seconds_in_a_year*5)));
    if (constraint['2'] == true) c2 = (tsp >= (cur_time - (seconds_in_a_year*10)));
    if (constraint['3'] == true) {
        if (constraint['min'] != '' && constraint['max'] != '') c3 = (tsp >= Math.floor(Date.parse(constraint['min']))/1000 && tsp <= Math.floor(Date.parse(constraint['max'])/1000));
        else if (constraint['min'] != '') c3 = (tsp >= Math.floor(Date.parse(constraint['min']))/1000);
        else if (constraint['max'] != '') c3 = (tsp <= Math.floor(Date.parse(constraint['max']))/1000);
    }
   return (c1 || c2 || c3);
}

// this is a bit faster than a.filter()
const fil = (fn, a) => {
    const f = []
    for (let i=0;i<a.length;i++) if (fn(a[i])) f.push(a[i]);
    return f;
};

const fil_add = (fn, a, s) => {
    for (let i=0;i<a.length;i++) if (fn(a[i])) s.add(a[i]);
};

const fil_cnt = (fn, a) => {
  let cnt = 0;
  for (let i=0;i<a.length;i++) if (fn(a[i])) cnt += 1;
  return cnt;
};

const all_ptt_set = new Set([...Array(all_ptt_cnt).keys()]);

//========================================================
// api to handle get_query_result
app.post("/get_query_result", (req, res) => {
    try {
        console.log('In /get_query_result', new Date());
        console.time('/get_query_result');
        const data = req.body;
        console.log(data);

        global_results[data.qid] = {tsp: Date.now()/1000};

        // snomed terms and time filter
        if (data.query.length == 0) {
            global_results[data.qid]['all'] = new Set(all_ptt_set);
            global_results[data.qid]['individual'] = [];
        } else {
            global_results[data.qid]['all'] = new Set();
            global_results[data.qid]['individual'] = [];
            let individual = [];
            let cui_or_group = [];
            let cui_and_group = [];
            for (let i=0; i < data.query.length; i++) {
                if (i%2 == 0) {
                    let s = null;
                    if (data.filter['time']['0']) {
                        if (data.query[i]['with'] == 'with' && data.query[i]['child'] == false) {
                            s = new Set([...cui2ptt_arr[cui_code2id[data.query[i]['cui']]]]);
                        } else if (data.query[i]['with'] == 'with' && data.query[i]['child'] == true) {
                            s = new Set();
                            const cuis = get_cui_child_terms(data.query[i]['cui']);
                            for (const cui of cuis) {const arr = cui2ptt_arr[cui_code2id[cui]]; for (const ptt of arr) s.add(ptt);}
                        } else if (data.query[i]['with'] == 'without' && data.query[i]['child'] == false) {
                            const s_all = new Set(all_ptt_set);
                            const s_cui = new Set([...cui2ptt_arr[cui_code2id[data.query[i]['cui']]]]);
                            s = new Set(fil(ptt => !s_cui.has(ptt), [...s_all]));
                        } else if (data.query[i]['with'] == 'without' && data.query[i]['child'] == true) {
                            const s_all = new Set(all_ptt_set);
                            const s_cui = new Set();
                            const cuis = get_cui_child_terms(data.query[i]['cui']);
                            for (const cui of cuis) {const arr = cui2ptt_arr[cui_code2id[cui]]; for (const ptt of arr) s_cui.add(ptt);}
                            s = new Set(fil(ptt => !s_cui.has(ptt), [...s_all]));
                        }
                    } else {
                        if (data.query[i]['with'] == 'with' && data.query[i]['child'] == false) {
                            s = new Set();
                            const es = fil(e => time_filter(data.filter['time'], e[1]), Object.entries(cui2ptt_tsp_arr[cui_code2id[data.query[i]['cui']]]));
                            for (const e of es) s.add(parseInt(e[0]));
                        } else if (data.query[i]['with'] == 'with' && data.query[i]['child'] == true) {
                            s = new Set();
                            const cuis = get_cui_child_terms(data.query[i]['cui']);
                            for (const cui of cuis) {
                                const es = fil(e => time_filter(data.filter['time'], e[1]), Object.entries(cui2ptt_tsp_arr[cui_code2id[cui]]));
                                for (const e of es) s.add(parseInt(e[0]));
                            }
                        } else if (data.query[i]['with'] == 'without' && data.query[i]['child'] == false) {
                            const s_all = new Set(all_ptt_set);
                            const s_cui = new Set();
                            const es = fil(e => time_filter(data.filter['time'], e[1]), Object.entries(cui2ptt_tsp_arr[cui_code2id[data.query[i]['cui']]]));
                            for (const e of es) s_cui.add(parseInt(e[0]));
                            s = new Set(fil(ptt => !s_cui.has(ptt), [...s_all]));
                        } else if (data.query[i]['with'] == 'without' && data.query[i]['child'] == true) {
                            const s_all = new Set(all_ptt_set);
                            const s_cui = new Set();
                            const cuis = get_cui_child_terms(data.query[i]['cui']);
                            for (const cui of cuis) {
                                const es = fil(e => time_filter(data.filter['time'], e[1]), Object.entries(cui2ptt_tsp_arr[cui_code2id[cui]]));
                                for (const e of es) s_cui.add(parseInt(e[0]));
                            }
                            s = new Set(fil(ptt => !s_cui.has(ptt), [...s_all]));
                        }
                    }
                    cui_and_group.push(s);
                    individual.push(s.size);
                } else if (i%2 != 0 && data.query[i]['str'] == 'or') {
                    let s = new Set(cui_and_group[0]);
                    for (let j=1,n=cui_and_group.length;j<n;j++) {const and_s = cui_and_group[j]; s = new Set(fil(ptt => and_s.has(ptt), [...s]));}
                    cui_or_group.push(s);
                    cui_and_group = [];
                }
            }
            let s = new Set(cui_and_group[0]);
            for (let j=1,n=cui_and_group.length;j<n;j++) {const and_s = cui_and_group[j]; s = new Set(fil(ptt => and_s.has(ptt), [...s]));}
            cui_or_group.push(s);
            cui_and_group = [];
            let s_final = new Set();
            for (let j=0,n=cui_or_group.length;j<n;j++) { const or_s = cui_or_group[j]; for (const ptt of or_s) s_final.add(ptt); }
            global_results[data.qid]['all'] = s_final;
            for (let j=0,n=individual.length;j<n;j++) global_results[data.qid]['individual'].push(individual[j]);
        }
        // apply filters
        let s_filter = [...global_results[data.qid]['all']];
        if (data.filter['gender']['0'] == false) {
            let s = new Set();
            if (data.filter['gender']['1']) fil_add((x) => ptt2sex_arr[x]==1, s_filter, s);
            if (data.filter['gender']['2']) fil_add((x) => ptt2sex_arr[x]==2, s_filter, s);
            if (data.filter['gender']['3']) fil_add((x) => ptt2sex_arr[x]==3, s_filter, s);
            s_filter = fil((x) => s.has(x), s_filter);
        }
        if (data.filter['alive']['0'] == false) {
            let s = new Set();
            if (data.filter['alive']['1']) fil_add((x) => ptt2dod_arr[x]==0, s_filter, s);
            if (data.filter['alive']['2']) fil_add((x) => ptt2dod_arr[x]!=0, s_filter, s);
            s_filter = fil((x) => s.has(x), s_filter);
        }
        if (data.filter['age']['0'] == false) {
            let s = new Set();
            if (data.filter['age']['1']) fil_add((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x]>=0 && ptt2age_arr[x]<=20, s_filter, s);
            if (data.filter['age']['2']) fil_add((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x]>20 && ptt2age_arr[x]<=40, s_filter, s);
            if (data.filter['age']['3']) fil_add((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x]>40 && ptt2age_arr[x]<=60, s_filter, s);
            if (data.filter['age']['4']) fil_add((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x]>60, s_filter, s);
            if (data.filter['age']['5']) fil_add((x) => ptt2dod_arr[x]==0 && age_custom_filter(data.filter['age'], ptt2age_arr[x]), s_filter, s);
            s_filter = fil((x) => s.has(x), s_filter);
        }
        if (data.filter['ethnicity']['0'] == false) {
            let s = new Set();
            if (data.filter['ethnicity']['1']) fil_add((x) => ptt2eth_arr[x]==1, s_filter, s);
            if (data.filter['ethnicity']['2']) fil_add((x) => ptt2eth_arr[x]==2, s_filter, s);
            if (data.filter['ethnicity']['3']) fil_add((x) => ptt2eth_arr[x]==3, s_filter, s);
            if (data.filter['ethnicity']['4']) fil_add((x) => ptt2eth_arr[x]==4, s_filter, s);
            if (data.filter['ethnicity']['5']) fil_add((x) => ptt2eth_arr[x]==5, s_filter, s);
            if (data.filter['ethnicity']['6']) fil_add((x) => ptt2eth_arr[x]==6, s_filter, s);
            s_filter = fil((x) => s.has(x), s_filter);
        }

        global_results[data.qid]['all'] = new Set([...s_filter]);

        const query_result = {
            all: global_results[data.qid]['all'].size,
            individual: global_results[data.qid]['individual']
        };
        console.timeEnd('/get_query_result');
        res.status(200).json({qid:data.qid, query_result:query_result}).end();
    } catch (err) {
        console.log('/get_query_result err:', err);
        res.status(200).json({query_result:{}}).end();
    }
});

//========================================================
// api to handle get_filter_result
app.post("/get_filter_result", (req, res) => {
    try {
        console.time('/get_filter_result');
        console.log('In /get_filter_result');
        const data = req.body;
        let filter_result = {
            'time': {  '0':'', '1':'', '2':'', '3':'' },
            'gender':{},
            'alive':{},
            'age':{},
            'ethnicity':{}
        };
        const all = [...global_results[data.qid]['all']];
        filter_result['gender']['0'] = all.length;
        filter_result['gender']['1'] = fil_cnt((x) => ptt2sex_arr[x]==1, all);
        filter_result['gender']['2'] = fil_cnt((x) => ptt2sex_arr[x]==2, all);
        filter_result['gender']['3'] = fil_cnt((x) => ptt2sex_arr[x]==3, all);
        filter_result['alive']['0'] = all.length;
        filter_result['alive']['1'] = fil_cnt((x) => ptt2dod_arr[x]==0, all);
        filter_result['alive']['2'] = fil_cnt((x) => ptt2dod_arr[x]!=0, all);
        filter_result['age']['0'] = fil_cnt((x) => ptt2dod_arr[x]==0, all);
        filter_result['age']['1'] = fil_cnt((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x] >=0 && ptt2age_arr[x] <=20, all);
        filter_result['age']['2'] = fil_cnt((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x] >20 && ptt2age_arr[x] <=40, all);
        filter_result['age']['3'] = fil_cnt((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x] >40 && ptt2age_arr[x] <=60, all);
        filter_result['age']['4'] = fil_cnt((x) => ptt2dod_arr[x]==0 && ptt2age_arr[x] >60, all);
        filter_result['age']['5'] = fil_cnt((x) => ptt2dod_arr[x]==0 && age_custom_filter(data.filter['age'], ptt2age_arr[x]), all); 
        filter_result['ethnicity']['0'] = all.length;
        filter_result['ethnicity']['1'] = fil_cnt((x) => ptt2eth_arr[x]==1, all);
        filter_result['ethnicity']['2'] = fil_cnt((x) => ptt2eth_arr[x]==2, all);
        filter_result['ethnicity']['3'] = fil_cnt((x) => ptt2eth_arr[x]==3, all);
        filter_result['ethnicity']['4'] = fil_cnt((x) => ptt2eth_arr[x]==4, all);
        filter_result['ethnicity']['5'] = fil_cnt((x) => ptt2eth_arr[x]==5, all);
        filter_result['ethnicity']['6'] = fil_cnt((x) => ptt2eth_arr[x]==6, all);
        console.timeEnd('/get_filter_result');
        res.status(200).json({qid:data.qid, filter_result:filter_result}).end();
    } catch (err) {
        console.log('/get_filter_result err:', err);
        res.status(200).json({filter_result:{}}).end();
    }
});
//========================================================

//========================================================
// api to handle get_age
app.post('/get_age', (req, res) => {
    try {
        console.time('/get_age');
        console.log('In /get_age');
        const data = req.body;
        const all = [...global_results[data.qid]['all']];
        const values = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110];
        let results = [];
        for (var i=0,n=values.length; i<n-1 ; i++) {
            if (i==0) {
                results.push(fil_cnt((x) => ptt2dod_arr[x]==0  && ptt2age_arr[x]>=values[i] && ptt2age_arr[x]<=values[i+1], all));
            } else {
                results.push(fil_cnt((x) => ptt2dod_arr[x]==0  && ptt2age_arr[x]>values[i] && ptt2age_arr[x]<=values[i+1], all));
            }
        }
        console.timeEnd('/get_age');
        res.status(200).json({qid:data.qid, data:results}).end();
    } catch (err) {
        console.log('/get_age err:', err);
        res.status(200).json({data:[]}).end();
    }
});
//========================================================

//========================================================
// api to handle get_top_terms
app.post('/get_top_terms', (req, res) => {
    try {
        console.log('In /get_top_terms');
        console.time('/get_top_terms');
        const data = req.body;
        let sortable = [];
        let result_arr = [];
        let treemap_data = [];
        let type_map = {};
        let ptt_list = [...global_results[data.qid]['all']];
        let cui_cnt_arr = new Array(all_cui_cnt).fill(0);
        for (const ptt of ptt_list) {const arr = ptt2cui_arr[ptt]; for (const cui of arr) cui_cnt_arr[cui] += 1;}
        for (let i=0,n=cui_cnt_arr.length;i<n;i++) {const cnt = cui_cnt_arr[i]; if (cnt>0) sortable.push( {cui:i, cnt:cnt} );}
        sortable.sort((a, b) => b.cnt - a.cnt);
        for (let i=0,n=sortable.length;i<n && i<300;i++) {const s = sortable[i]; result_arr.push( {str:snomed_terms[s.cui].str, cnt:s.cnt} );}
        for (let i=0,n=result_arr.length;i<n && i<300;i++) {
            const r = result_arr[i];
            const str = r['str'];
            const cnt = r['cnt'];
            const type = str.slice(str.lastIndexOf('(')+1, str.length-1);
            if (type in type_map) {
                treemap_data[type_map[type]]['value'] += cnt;
                treemap_data[type_map[type]]['children'].push({name: str, value: cnt});
            } else {
                type_map[type] = treemap_data.length;
                treemap_data.push( { name: type, value: cnt, children: [{name: str, value: cnt}] } );
            }
        }
        console.timeEnd('/get_top_terms');
        res.status(200).json({qid:data.qid, data:treemap_data, result_arr:result_arr}).end();
    } catch (err) {
        console.log('/get_top_terms err:', err);
        res.status(200).json({data:{}, result_arr:[]}).end();
    }
});
//========================================================

//========================================================
// api to handle get_top_terms
app.post('/compare_query', (req, res) => {
    try {
        console.log('In /compare_query');
        console.time('/compare_query');
        const data = req.body;
        let result_arr = [];
        const all = new Set(global_results[data.qid]['all']);
        for (let i=0,n=data.compare_query.length; i<n; i++) {
            let s = new Set();
            if (data.compare_query[i]['child'] == true) {
                const a = new Set();
                const cuis = get_cui_child_terms(data.compare_query[i]['cui']);
                for (const cui of cuis) { const arr = cui2ptt_arr[cui_code2id[cui]]; for(const ptt of arr) a.add(ptt); }
                for (const ptt of a) if (all.has(ptt)) s.add(ptt);
            } else {
                const a = new Set(cui2ptt_arr[cui_code2id[data.compare_query[i]['cui']]]);
                for (const ptt of a) if (all.has(ptt)) s.add(ptt); 
            }
            result_arr.push({str: data.compare_query[i]['str'], cnt: s.size});
        }
        console.timeEnd('/compare_query');
        res.status(200).json({qid:data.qid, data:result_arr}).end();
    } catch (err) {
        console.log('/compare_query err:', err);
        res.status(200).json({data:[]}).end();
    }
});
//========================================================

//========================================================
// api to handle remove_temp_table
app.post('/remove_result', (req, res) => {
    try {
        console.log('In /remove_result');
        const data = req.body;
        if (data.qid in global_results) {
            delete global_results[data.qid];
        }
        res.status(200).json({qid:data.qid, msg:'OK'}).end();
    } catch (err) {
        console.log('/remove_result err:', err);
        res.status(200).json({msg:'Error'}).end();
    }
});
//========================================================

app.listen(3000, () => {
    console.log("Server listening on localhost port 3000");
});

// update everyday
setTimeout(() => {
    cur_tsp = Math.floor(Date.now() / 1000);
    cur_time = cur_tsp;
    Object.keys(global_results).forEach(qid => {
        if (cur_tsp - global_results[qid]['tsp'] > (60*60*24)) delete global_results[qid];
    });
}, 1000 * 60 * 60 * 24);