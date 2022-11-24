// Use this script to generate random data for the app
// Run this script with the command:
// node --max-old-space-size=32768 gen_random_data.js
console.log('Generating random data')
const fs = require('fs');
snomed_terms = require('./snomed_terms.json');

// Returns a random integer between min (inclusive) and max (inclusive).
function random_int(min, max) {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

const sex_id2code = ['Male', 'Female', 'Unknown']
const eth_id2code = ['Asian', 'Black', 'White', 'Mixed', 'Other', 'Unknown'];
let ptt2age = {};
let ptt2sex = {};
let ptt2eth = {};
let ptt2dod = {};
let cui2ptt_pos = {};
let cui2ptt_tsp = {};

let ptt_num = 1000000;
let max_ptt = 1000; // max. number of ptt a term can have
let max_age = 100;
let die_pct = 10; // percentage of died ptt = 1 / die_pct

// generate ptt_num random patient data
for (let i=0;i<ptt_num;i++) {
    ptt2age[i] = random_int(0,max_age);
    ptt2sex[i] = sex_id2code[random_int(0,sex_id2code.length-1)];
    ptt2eth[i] = eth_id2code[random_int(0,eth_id2code.length-1)];
    ptt2dod[i] = random_int(0,die_pct) == 0 ? random_int(Math.floor(Date.now()/1000) - (60*60*24*365*10), Math.floor(Date.now()/1000)) : 0;
    if (i%100000 == 0) console.log('ptt:', i, `${Math.floor((i/ptt_num)*100)}%`);
}

// for each snomed terms, generate some random mention data
for (let i=0;i<snomed_terms.length;i++) {
    let picked = {};
    cui2ptt_pos[i] = {};
    cui2ptt_tsp[i] = {};
    for (let j=0;j<random_int(0,max_ptt);j++) {
        let ptt = random_int(0, ptt_num-1);
        while (picked[ptt]) ptt = random_int(0, ptt_num-1);
        picked[ptt] = true;
        cui2ptt_pos[i][ptt] = random_int(1,100);
        cui2ptt_tsp[i][ptt] = random_int(Math.floor(Date.now()/1000) - (60*60*24*365*10), Math.floor(Date.now()/1000));
    }
    if (i%100000 == 0) console.log('men:', i, `${Math.floor((i/snomed_terms.length)*100)}%`);
}

// write to files
console.log('writing to files')
fs.writeFileSync('ptt2age.json', JSON.stringify(ptt2age));
fs.writeFileSync('ptt2sex.json', JSON.stringify(ptt2sex));
fs.writeFileSync('ptt2eth.json', JSON.stringify(ptt2eth));
fs.writeFileSync('ptt2dod.json', JSON.stringify(ptt2dod));
const pos_out = fs.createWriteStream('cui2ptt_pos.jsonl', {flags: 'a'});
const tsp_out = fs.createWriteStream('cui2ptt_tsp.jsonl', {flags: 'a'});
Object.keys(cui2ptt_pos).forEach( k => { pos_out.write(`{"${snomed_terms[k]['cui']}":` + JSON.stringify(cui2ptt_pos[k]) + '}\n'); });
Object.keys(cui2ptt_tsp).forEach( k => { tsp_out.write(`{"${snomed_terms[k]['cui']}":` + JSON.stringify(cui2ptt_tsp[k]) + '}\n'); });
console.log('Finished generating random data')