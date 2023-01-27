clear
clc

load e.mat

clear par
par.run = 1;
par.redo = 0;
run_list = e.getSerie('run').removeEmpty();
run_list = run_list(1);

%%

par.volume   = run_list.getVolume('^s.wts_OC');
par.confound = run_list.getRP('multiple_regressors');
par.mask_threshold = 0.1;
par.atlas_name = 'aal3';


t0 = tic;
TS = job_extract_timeseries_from_atlas(par);
TS = job_timeseries_to_connectivity_matrix(TS);
plot_resting_state_connectivity_matrix(TS, {run_list.getExam().name})
TS = job_timeseries_to_connectivity_seedbased_pearson_zfisher(TS);
toc(t0);
