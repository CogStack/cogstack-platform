function data() {
  return {

    isTimeMenuOpen: true,
    toggleTimeMenu() {
      this.isTimeMenuOpen = ! this.isTimeMenuOpen;
    },
    isGenderMenuOpen: true,
    toggleGenderMenu() {
      this.isGenderMenuOpen = !this.isGenderMenuOpen;
    },
    isAliveMenuOpen: true,
    toggleAliveMenu() {
      this.isAliveMenuOpen = !this.isAliveMenuOpen;
    },
    isAgeMenuOpen: true,
    toggleAgeMenu() {
      this.isAgeMenuOpen = !this.isAgeMenuOpen;
    },
    isEthnicityMenuOpen: true,
    toggleEthnicityMenu() {
      this.isEthnicityMenuOpen = !this.isEthnicityMenuOpen;
    },
    isSideMenuOpen: false,
    toggleSideMenu() {
      this.isSideMenuOpen = !this.isSideMenuOpen;
    },
    closeSideMenu() {
      this.isSideMenuOpen = false;
    },
    isSettingMenuOpen: false,
    toggleSettingMenu() {
      this.isSettingMenuOpen = !this.isSettingMenuOpen;
    },
    closeSettingMenu() {
      this.isSettingMenuOpen = false;
    },

    search_bar_with: "with",
    search_bar_text: "",
    search_bar_suggestions: [],
    cancel_suggestions() {
      this.search_bar_text = "";
      this.search_bar_suggestions = [];
    },
    async handle_search_bar_text_input() {
      let text = this.search_bar_text.replace(/\W/g, ' ').replace(/\s+/g, ' ').trim();
      if (text.length > 0) {
        const data = {text: text};
        let resp = {};
        try {
          resp = await(await fetch("/keywords", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(data)
          })).json();
        } catch (err) {
          console.log('handle_search_bar_text_input (err):', err);
          this.search_bar_suggestions = [];
          return;
        }
        this.search_bar_suggestions = resp;
      } else {
        this.search_bar_suggestions = [];
      }
    },
    handle_select_suggestion(suggestion) {
      this.search_bar_text = "";
      this.search_bar_suggestions = [];
      const q = {
        cui: suggestion.cui,
        str: suggestion.str,
        with: this.search_bar_with,
        child: this.include_child_terms
      };
      if (this.query.length == 0) {
        this.query = [q];
      } else {
        this.query = [...this.query, {str:'and'}, q];
      }
      this.index_query();
      this.submit_query();
    },

    filter: {
      'time': {
        '0': true,
        '1': false,
        '2': false,
        '3': false,
        'min': '',
        'max': ''
      },
      'gender': {
        '0': true,
        '1': false,
        '2': false,
        '3': false
      },
      'alive': {
        '0': true,
        '1': false,
        '2': false     
      },
      'age': {
        '0': true,
        '1': false,
        '2': false,
        '3': false,
        '4': false,
        '5': false,
        'min': '',
        'max': ''
      },
      'ethnicity': {
        '0': true,
        '1': false,
        '2': false,
        '3': false,
        '4': false,
        '5': false,
        '6': false
      }
    },
    handle_filter_change_time(ind) {
      if (this.filter['time']['0'] == false && this.filter['time']['1'] == false && this.filter['time']['2'] == false && this.filter['time']['3'] == false) {
        this.filter['time']['0'] = true;
        this.filter['time']['1'] = false;
        this.filter['time']['2'] = false;
        this.filter['time']['3'] = false;
      } else if (ind=='0' && this.filter['time']['0'] == true) {
        this.filter['time']['1'] = false;
        this.filter['time']['2'] = false;
        this.filter['time']['3'] = false;
      } else if (ind!='0') {
        this.filter['time']['0'] = false;
      }
      this.submit_query();
    },
    handle_filter_change_time_custom() {
      console.log(`min_time: '${this.filter['time']['min']}'`);
      console.log(`max_time: '${this.filter['time']['max']}'`);
      if (this.filter['time']['min'] == '' && this.filter['time']['max'] == '') {
        this.filter['time']['3'] = false;
      } else {
        this.filter['time']['3'] = true;
      }
      this.handle_filter_change_time('3');
    },
    handle_filter_change_gender(ind) {
      if (this.filter['gender']['0'] == false && this.filter['gender']['1'] == false && this.filter['gender']['2'] == false && this.filter['gender']['3'] == false) {
        this.filter['gender']['0'] = true;
        this.filter['gender']['1'] = false;
        this.filter['gender']['2'] = false;
        this.filter['gender']['3'] = false;
      } else if (ind=='0' && this.filter['gender']['0'] == true) {
        this.filter['gender']['1'] = false;
        this.filter['gender']['2'] = false;
        this.filter['gender']['3'] = false;
      } else if (ind!='0') {
        this.filter['gender']['0'] = false;
      }
      this.submit_query();
    },
    handle_filter_change_alive(ind) {
      if (this.filter['alive']['0'] == false && this.filter['alive']['1'] == false && this.filter['alive']['2'] == false) {
        this.filter['alive']['0'] = true;
        this.filter['alive']['1'] = false;
        this.filter['alive']['2'] = false;
      } else if (ind=='0' && this.filter['alive']['0'] == true) {
        this.filter['alive']['1'] = false;
        this.filter['alive']['2'] = false;
      } else if (ind!='0') {
        this.filter['alive']['0'] = false;
      }
      this.submit_query();
    },
    handle_filter_change_age(ind) {
      if (this.filter['age']['0'] == false && this.filter['age']['1'] == false && this.filter['age']['2'] == false && this.filter['age']['3'] == false && this.filter['age']['4'] == false && this.filter['age']['5'] == false) {
        this.filter['age']['0'] = true;
        this.filter['age']['1'] = false;
        this.filter['age']['2'] = false;
        this.filter['age']['3'] = false;
        this.filter['age']['4'] = false;
        this.filter['age']['5'] = false;
      } else if (ind=='0' && this.filter['age']['0'] == true) {
        this.filter['age']['1'] = false;
        this.filter['age']['2'] = false;
        this.filter['age']['3'] = false;
        this.filter['age']['4'] = false;
        this.filter['age']['5'] = false;
      } else if (ind!='0') {
        this.filter['age']['0'] = false;
      }
      this.submit_query();
    },
    handle_filter_change_age_custom() {
      if (this.filter['age']['min'] == '' && this.filter['age']['max'] == '') {
        this.filter['age']['5'] = false;
      } else {
        this.filter['age']['5'] = true;
      }
      this.handle_filter_change_age('5');
    },
    handle_filter_change_ethnicity(ind) {
      if (this.filter['ethnicity']['0'] == false && this.filter['ethnicity']['1'] == false && this.filter['ethnicity']['2'] == false && this.filter['ethnicity']['3'] == false && this.filter['ethnicity']['4'] == false && this.filter['ethnicity']['5'] == false && this.filter['ethnicity']['6'] == false) {
        this.filter['ethnicity']['0'] = true;
        this.filter['ethnicity']['1'] = false;
        this.filter['ethnicity']['2'] = false;
        this.filter['ethnicity']['3'] = false;
        this.filter['ethnicity']['4'] = false;
        this.filter['ethnicity']['5'] = false;
        this.filter['ethnicity']['6'] = false;
      } else if (ind=='0' && this.filter['ethnicity']['0'] == true) {
        this.filter['ethnicity']['1'] = false;
        this.filter['ethnicity']['2'] = false;
        this.filter['ethnicity']['3'] = false;
        this.filter['ethnicity']['4'] = false;
        this.filter['ethnicity']['5'] = false;
        this.filter['ethnicity']['6'] = false;
      } else if (ind!='0') {
        this.filter['ethnicity']['0'] = false;
      }
      this.submit_query();
    },

    clear_all_filters() {
      this.filter = {
        'time': {
          '0': true,
          '1': false,
          '2': false,
          '3': false,
          'min': '',
          'max': ''
        },
        'gender': {
          '0': true,
          '1': false,
          '2': false,
          '3': false
        },
        'alive': {
          '0': true,
          '1': false,
          '2': false     
        },
        'age': {
          '0': true,
          '1': false,
          '2': false,
          '3': false,
          '4': false,
          '5': false,
          'min': '',
          'max': ''
        },
        'ethnicity': {
          '0': true,
          '1': false,
          '2': false,
          '3': false,
          '4': false,
          '5': false,
          '6': false
        }
      };
    },

    clear_all_filters_and_submit() {
      this.filter = {
        'time': {
          '0': true,
          '1': false,
          '2': false,
          '3': false,
          'min': '',
          'max': ''
        },
        'gender': {
          '0': true,
          '1': false,
          '2': false,
          '3': false
        },
        'alive': {
          '0': true,
          '1': false,
          '2': false     
        },
        'age': {
          '0': true,
          '1': false,
          '2': false,
          '3': false,
          '4': false,
          '5': false,
          'min': '',
          'max': ''
        },
        'ethnicity': {
          '0': true,
          '1': false,
          '2': false,
          '3': false,
          '4': false,
          '5': false,
          '6': false
        }
      };
      this.submit_query();
    },

    query: [],
    include_child_terms: true,

    save_query() {
      let file = {
        query: this.query,
        filter: this.filter,
        compare_query: this.compare_query
      };
      var a = document.createElement("a");
      a.href = window.URL.createObjectURL(new Blob([`${JSON.stringify(file)}`], {type: "text/plain"}));
      a.download = "query.txt";
      a.click();
      a.remove();
    },
    load_query_panel_show: false,
    load_query() {
      this.load_query_panel_show = true;
      const fileSelector = document.getElementById('file_selector');
      fileSelector.addEventListener('change', this.handle_load_query.bind(this));
      console.log('load_query');
    },
    handle_load_query(event) {
        const file = event.target.files[0];
        const reader = new FileReader();
        reader.addEventListener('load', (load_event) => {
            const loaded = JSON.parse(load_event.target.result);
            this.query = loaded.query;
            this.filter = loaded.filter;
            this.compare_query = loaded.compare_query;
            this.load_query_panel_show = false;
            this.submit_query();
        });
        reader.readAsText(file);
        const fileSelector = document.getElementById('file_selector');
        fileSelector.removeEventListener('change', this.handle_load_query.bind(this));
    },
    admin_logged_in: false,
    admin_login_panel_show: false,
    admin_password_input: '',
    admin_login_message: ' ',
    admin_login() {
      this.admin_login_panel_show = true;
      console.log('admin_login');
    },
    async handle_admin_login() {
      try {
        resp = await(await fetch("/admin_login", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({'password':this.admin_password_input})
        })).json();
        console.log(resp)
        if (resp.msg == 'ok') {
          this.admin_logged_in = true;
          this.admin_login_panel_show = false,
          this.admin_password_input = '';
          this.admin_login_message = ' '
        } else {
          this.admin_logged_in = false;
          this.admin_password_input = '';
          this.admin_login_message = 'Passowrd incorrect. Please try again.'
        }
      } catch (err) {
        console.log('fetch("/admin_login") (err):', err);
        this.running_status = 'Something went wrong in the server, please try again later.';
        this.admin_logged_in = false;
        this.admin_login_panel_show = false;
        this.admin_password_input = '';
        this.admin_login_message = ' ';
        this.reset_results();
        this.clear_charts();
        return;
      }
    },
    async admin_logout() {
      try {
        resp = await(await fetch("/admin_logout", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({'msg':'logout'})
        })).json();
        console.log(resp)
        this.admin_logged_in = false;
        this.admin_login_panel_show = false;
        this.admin_password_input = '';
        this.admin_login_message = ' ';
      } catch (err) {
        console.log('fetch("/admin_logout") (err):', err);
        this.running_status = 'Something went wrong in the server, please try again later.';
        this.admin_logged_in = false;
        this.admin_login_panel_show = false;
        this.admin_password_input = '';
        this.admin_login_message = ' ';
        this.reset_results();
        this.clear_charts();
        return;
      }
    },
    async export_patients() {
      try {
        resp = await(await fetch("/export", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({'qid':this.qid})
        })).json();
        if (resp.msg && resp.msg == 'error') {
          return;
        } else {
          let csvContent = "data:text/csv;charset=utf-8," + "pateint_id\n" + resp.ptt_codes.join("\n");
          var encodedUri = encodeURI(csvContent);
          window.open(encodedUri);
        }
      } catch (err) {
        console.log('fetch("/export") (err):', err);
        this.running_status = 'Something went wrong in the server, please try again later.';
        return;
      }
    },
    index_query() {
      this.query.forEach((q,i)=> q['ind'] = i);
    },
    delete_query(q_ind) {
      if (q_ind == 0) this.query = this.query.slice(2);
      else this.query.splice(q_ind-1, 2);
      if (this.query.length == 0) {this.include_child_terms = true; this.clear_all_filters(); }
      this.index_query();
      this.submit_query();
    },
    convert_and_or(q_ind) {
      if (this.query[q_ind]['str'] == "and") this.query[q_ind]['str'] = "or"
      else this.query[q_ind]['str'] = "and"
      this.submit_query();
    },
    handle_include_child_terms_change() {
      this.query.forEach((q,i) => {
        if (i%2 == 0) q['child'] = this.include_child_terms;
      });
      this.submit_query();
    },
    handle_and() {
      this.query.forEach((q,i) => {
        if (i%2 != 0) q['str'] = 'and';
      });
      this.submit_query();
    },
    handle_or() {
      this.query.forEach((q,i) => {
        if (i%2 != 0) q['str'] = 'or';
      });
      this.submit_query();
    },
    handle_clear() {
      this.query = [];
      this.search_bar_with = "with";
      this.search_bar_text = "";
      this.search_bar_suggestions = [];
      this.include_child_terms = true;
      this.clear_all_filters();
      this.reset_results();
      this.submit_query();
    },

    qry_cnt: 0,
    qid: null,
    running_status: '',
    async submit_query() {
      const this_qry_cnt = this.qry_cnt + 1;
      this.qry_cnt = this_qry_cnt;
      this.reset_results();
      const qid = Math.random().toString().replace('.', '');
      this.qid = qid;

      const data = {qid:qid, query: this.query, filter:this.filter};

      this.running_status = 'getting total count...';
      let query_result_resp = {};
      try {
        query_result_resp = await(await fetch("/get_query_result", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data)
        })).json();
      } catch (err) {
        console.log('fetch("/get_query_result") (err):', err);
        this.running_status = 'Something went wrong in the server, please try again later.';
        this.reset_results();
        this.clear_charts();
        return;
      }
      if (query_result_resp.query_result['all'] <= 20) {
        this.running_status = 'The patient count is too low, please try another query.';
        this.reset_results();
        this.clear_charts();
        return;
      }

      if (!query_result_resp.query_result.hasOwnProperty('all')) {
        this.running_status = 'Something went wrong in the server, please try again later.';
        this.reset_results();
        this.clear_charts();
        return;
      }

      this.query_result = query_result_resp.query_result;
      console.log(this.query_result);

      this.running_status = 'getting filter count...';
      if (this_qry_cnt == this.qry_cnt) {
        let filter_result_resp = {};
        try {
          filter_result_resp = await(await fetch("/get_filter_result", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(data)
          })).json();
        } catch (err) {
          console.log('fetch("/get_filter_result") (err):', err);
          this.running_status = 'Something went wrong in the server, please try again later.';
          this.reset_results();
          this.clear_charts();
          return;
        }
        this.filter_result = filter_result_resp.filter_result;
        console.log(this.filter_result);
      }

      if (this_qry_cnt == this.qry_cnt) this.draw_gender_chart();
      if (this_qry_cnt == this.qry_cnt) this.draw_alive_chart();
      if (this_qry_cnt == this.qry_cnt) {
        this.running_status = 'drawing age chart...';
        try {
          await this.draw_age_chart(qid);
        } catch (err) {
          console.log('await this.draw_age_chart(qid) (err):', err);
          this.running_status = 'Something went wrong in the server, please try again later.';
          this.reset_results();
          this.clear_charts();
          return;
        }
      }
      if (this_qry_cnt == this.qry_cnt) this.draw_ethnicity_chart();
      if (this_qry_cnt == this.qry_cnt) {
        this.running_status = 'getting top common terms...';
        try {
          await this.draw_top_terms_chart(qid);
        } catch (err) {
          console.log('await this.draw_top_terms_chart(qid); (err):', err);
          this.running_status = 'Something went wrong in the server, please try again later.';
          this.reset_results();
          this.clear_charts();
          return;
        }
      }
      if (this_qry_cnt == this.qry_cnt) this.fill_top_disorder_table(qid);
      if (this_qry_cnt == this.qry_cnt) this.fill_top_finding_table(qid);
      if (this_qry_cnt == this.qry_cnt) this.fill_top_procedure_table(qid);
      if (this_qry_cnt == this.qry_cnt) this.fill_top_substance_table(qid);
      if (this_qry_cnt == this.qry_cnt) {
        this.running_status = 'getting compare terms...';
        try {
          await this.submit_compare_query();
        } catch (err) {
          console.log('await this.submit_compare_query();', err);
          this.running_status = 'Something went wrong in the server, please try again later.';
          this.reset_results();
          this.clear_charts();
          return;
        }
      }
      if (this_qry_cnt == this.qry_cnt) this.running_status = 'Done';
    },

    query_result: {
      all: '---',
      individual: []
    },
    filter_result: {
      'time': {
        '0': '',
        '1': '',
        '2': '',
        '3': ''
      },
      'gender': {
        '0': '---',
        '1': '---',
        '2': '---',
        '3': '---'
      },
      'alive': {
        '0': '---',
        '1': '---',
        '2': '---'     
      },
      'age': {
        '0': '---',
        '1': '---',
        '2': '---',
        '3': '---',
        '4': '---',
        '5': '---',
        'min': '',
        'max': ''
      },
      'ethnicity': {
        '0': '---',
        '1': '---',
        '2': '---',
        '3': '---',
        '4': '---',
        '5': '---',
        '6': '---'
      }
    },
    reset_results() {
      this.query_result = {
        all: '---',
        individual: []
      },
      this.filter_result = {
        'time': {
          '0': '',
          '1': '',
          '2': '',
          '3': ''
        },
        'gender': {
          '0': '---',
          '1': '---',
          '2': '---',
          '3': '---'
        },
        'alive': {
          '0': '---',
          '1': '---',
          '2': '---'     
        },
        'age': {
          '0': '---',
          '1': '---',
          '2': '---',
          '3': '---',
          '4': '---',
          '5': '---',
          'min': '',
          'max': ''
        },
        'ethnicity': {
          '0': '---',
          '1': '---',
          '2': '---',
          '3': '---',
          '4': '---',
          '5': '---',
          '6': '---'
        }
      }
    },

    clear_charts() {
      var gender_chart = echarts.init(document.getElementById('gender_chart'));
      gender_chart.clear();
      var alive_chart = echarts.init(document.getElementById('alive_chart'));
      alive_chart.clear();
      var age_chart = echarts.init(document.getElementById('age_chart'));
      age_chart.clear()
      var ethnicity_chart = echarts.init(document.getElementById('ethnicity_chart'));
      ethnicity_chart.clear();
      var top_terms_chart = echarts.init(document.getElementById('top_terms_chart'));
      top_terms_chart.clear();
      var compare_chart = echarts.init(document.getElementById('compare_chart'));
      compare_chart.clear();
      this.top_disorders = [];
      this.top_findings = [];
      this.top_procedures = [];
      this.top_substances = [];
    },

    draw_gender_chart() {
      var gender_chart = echarts.init(document.getElementById('gender_chart'));
      var option = {
        series: [{
          type: 'pie',
          data: [
            { value: this.filter_result['gender']['1'], name: 'Male'},
            { value: this.filter_result['gender']['2'], name: 'Female'},
            { value: this.filter_result['gender']['3'], name: 'Unknown'}],
          radius: ['50%', '80%'],
          label: {
            formatter: '{b}: ({d}%)'
          }
        }]
      };
      gender_chart.setOption(option);
    },
    draw_alive_chart() {
      var alive_chart = echarts.init(document.getElementById('alive_chart'));
      var option = {
        series: [{
          type: 'pie',
          data: [
            { value: this.filter_result['alive']['1'], name: 'Alive'},
            { value: this.filter_result['alive']['2'], name: 'Died'}],
          radius: ['50%', '80%'],
          label: {
            formatter: '{b}: ({d}%)'
          }
        }]
      };
      alive_chart.setOption(option);
    },

    age_chart_updating: false,
    async draw_age_chart(qid) {
      this.age_chart_updating = true;
      // get data
      let resp = {};
      try {
        resp = await(await fetch("/get_age", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({qid:qid})
        })).json();
      } catch (err) {
        console.log('fetch("/get_age") (err):', err);
      }
      var age_chart = echarts.init(document.getElementById('age_chart'));
      var option = {
        xAxis: [ { type: 'value', name: 'Age' } ],
        yAxis: [ { type: 'value', name: 'Count'  } ],
        tooltip: [{show: true}],
        series: [ { name: 'Age', type: 'bar', barWidth: '99%', data: resp.data.map((x,i) => [(i*10)+5, x]) } ]
      };
      age_chart.setOption(option);
      this.age_chart_updating = false;
    },

    draw_ethnicity_chart() {
      var ethnicity_chart = echarts.init(document.getElementById('ethnicity_chart'));
      var option = {
        xAxis: [ { type: 'category', name: 'ethnicity', data: ['Asian', 'Black', 'White', 'Mixed', 'Other', 'Unknown'] } ],
        yAxis: [ { type: 'value', name: 'Count'  } ],
        tooltip: [{show: true}],
        series: [ { name: 'ethnicity', type: 'bar', barWidth: '60%', data:  [...Array(6).keys()].map(x => this.filter_result['ethnicity'][`${x+1}`])} ]
      };
      ethnicity_chart.setOption(option);
    },

    result_arr: [],
    top_terms_chart_updating: false,
    async draw_top_terms_chart(qid) {
      //get data
      this.top_terms_chart_updating = true;
      let resp = {};
      try {
        resp = await(await fetch("/get_top_terms", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({qid:qid, query: this.query, filter:this.filter})
        })).json();
      } catch (err) {
        console.log('fetch("//et_top_terms") (err):', err);
      }
      console.log(resp.data);
      this.result_arr = [...resp.result_arr];

      var top_terms_chart = echarts.init(document.getElementById('top_terms_chart'));
      var option = {
        series: [{type: 'treemap',data: resp.data}],
        tooltip: [{show: true}],
      };
      top_terms_chart.setOption(option);
      this.top_terms_chart_updating = false;
    },

    show_disorders_table: true,
    show_findings_table: false,
    show_procedures_table: false,
    show_substances_table: false,
    page: 1,
    change_table(tab) {
      if (tab == 'disorders') {this.show_disorders_table=true; this.show_findings_table=false; this.show_procedures_table=false; this.show_substances_table=false; this.page=1;}
      else if (tab == 'findings') {this.show_disorders_table=false; this.show_findings_table=true; this.show_procedures_table=false; this.show_substances_table=false; this.page=1;}
      else if (tab == 'procedures') {this.show_disorders_table=false; this.show_findings_table=false; this.show_procedures_table=true; this.show_substances_table=false; this.page=1;}
      else if (tab == 'substances') {this.show_disorders_table=false; this.show_findings_table=false; this.show_procedures_table=false; this.show_substances_table=true; this.page=1;}
    },

    top_disorder_table_updating: false,
    top_disorders: [],
    fill_top_disorder_table(qid) {
      this.top_disorders = [];
      this.top_disorder_table_updating = true;
      for (let i = 0; i < this.result_arr.length; i++) {
        if (this.result_arr[i]['str'].search('(disorder)') != -1) {
          this.top_disorders.push({...this.result_arr[i]});
          if (this.top_disorders.length >= 50) {
            break;
          }
        }
      }
      this.top_disorder_table_updating = false;
    },

    top_finding_table_updating: false,
    top_findings: [],
    fill_top_finding_table(qid) {
      this.top_findings = [];
      this.top_finding_table_updating = true;
      for (let i = 0; i < this.result_arr.length; i++) {
        if (this.result_arr[i]['str'].search('(finding)') != -1) {
          this.top_findings.push({...this.result_arr[i]});
          if (this.top_findings.length >= 50) {
            break;
          }
        }
      }
      this.top_finding_table_updating = false;
    },

    top_procedure_table_updating: false,
    top_procedures: [],
    async fill_top_procedure_table(qid) {
      this.top_procedures = [];
      this.top_procedure_table_updating = true;
      for (let i = 0; i < this.result_arr.length; i++) {
        if (this.result_arr[i]['str'].search('(procedure)') != -1) {
          this.top_procedures.push({...this.result_arr[i]});
          if (this.top_procedures.length >= 50) {
            break;
          }
        }
      }
      this.top_procedure_table_updating = false;
    },

    top_substance_table_updating: false,
    top_substances: [],
    async fill_top_substance_table(qid) {
      this.top_substances = [];
      this.top_substance_table_updating = true;
      for (let i = 0; i < this.result_arr.length; i++) {
        if (this.result_arr[i]['str'].search('(substance)') != -1) {
          this.top_substances.push({...this.result_arr[i]});
          if (this.top_substances.length >= 50) {
            break;
          }
        }
      }
      this.top_substance_table_updating = false;
    },


    compare_query: [
      {cui: '53741008', str: 'Coronary arteriosclerosis (disorder)', with: 'with', child: true},
      {cui: '22298006', str: 'Myocardial infarction (disorder)', with: 'with', child: true},
      {cui: '230690007', str: 'Cerebrovascular accident (disorder)', with: 'with', child: true},
      {cui: '266257000', str: 'Transient ischemic attack (disorder)', with: 'with', child: true},
      {cui: '400047006', str: 'Peripheral vascular disease (disorder)', with: 'with', child: true},
      {cui: '67362008', str: 'Aortic aneurysm (disorder)', with: 'with', child: true}
    ],
    compare_query_search_bar_text: '',
    compare_query_search_bar_with: 'with',
    compare_query_search_bar_suggestions: [],
    compare_query_include_child_terms: true,
    compare_query_updating: false,
    index_compare_query() {
      this.compare_query.forEach((q,i)=> q['ind'] = i);
    },
    delete_compare_query(q_ind) {
      this.compare_query.splice(q_ind, 1);
      if (this.compare_query.length == 0) this.compare_query_include_child_terms = true;
      this.index_compare_query();
      this.submit_compare_query();
    },
    compare_query_cancel_suggestions() {
      this.compare_query_search_bar_text = "";
      this.compare_query_search_bar_suggestions = [];
    },
    handle_compare_query_include_child_terms_change() {
      this.compare_query.forEach((q,i) => {
        q['child'] = this.compare_query_include_child_terms;
      });
      this.submit_compare_query();
    },
    async handle_compare_query_search_bar_text_input() {
      let text = this.compare_query_search_bar_text.replace(/\W/g, ' ').replace(/\s+/g, ' ').trim();
      if (text.length > 0) {
        const data = {text: text};
        let resp = {};
        try {
          resp = await (await fetch("/keywords", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(data)
          })).json();
        } catch (err) {
          console.log('handle_compare_query_search_bar_text_input fetch() (err):', err);

        }
        this.compare_query_search_bar_suggestions = resp;
      } else {
        this.compare_query_search_bar_suggestions = [];
      }
    },
    handle_compare_query_select_suggestion(suggestion) {
      this.compare_query_search_bar_text = "";
      this.compare_query_search_bar_suggestions = [];
      const q = {
        cui: suggestion.cui,
        str: suggestion.str,
        with: this.compare_query_search_bar_with,
        child: this.compare_query_include_child_terms
      };
      if (this.compare_query.length == 0) this.compare_query = [q];
      else this.compare_query = [...this.compare_query, q];
      this.index_compare_query();
      this.submit_compare_query();
    },
    async submit_compare_query() {
      this.running_status = 'getting compare terms...'
      this.compare_query_updating = true;
      if (this.qid == null) return;
      let resp = {};
      try {
        resp = await(await fetch("/compare_query", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({qid:this.qid, compare_query: this.compare_query})
        })).json();
      } catch (err) {
        console.log('submit_compare_query fetch("/compare_query") (err):', err);
      }
      console.log(resp);
      var compare_chart = echarts.init(document.getElementById('compare_chart'));
      var option = {
        xAxis: [ { type: 'category', name: 'Term', data: resp.data.map(x => x['str']), axisLabel: { interval: 0, rotate: 10 } } ],
        yAxis: [ { type: 'value', name: 'Count'  } ],
        tooltip: [{show: true}],
        series: [ { name: 'Term', type: 'bar', barWidth: '60%', data: resp.data.map(x => x['cnt'])} ]
      };
      compare_chart.setOption(option);
      this.running_status = 'Done'
      this.compare_query_updating = false;
    },


  }
}




