clear
clc

load e
clear par

model_name = 'SimpleMotor2_reg';

dirStats = e.mkdir('glm',model_name);
dirFunc  = get_parent_path( e.getSerie('run_SimpleMotor2').getVolume('s5wts').toJob() );
dirFunc   = cellfun(@cellstr, dirFunc, 'UniformOutput', 0);

onsetspath = '/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/ECODYST/onsets';
e.getSerie('run_SimpleMotor2').addStim(onsetspath, 'SimpleMotor_run02_SPM_event.mat', model_name)
onsets = e.getSerie('run_SimpleMotor2').getStim(model_name).toJob(0);


%%

e.getSerie('run_SimpleMotor2').addStim(onsetspath, 'run02__R_IO1__reg.mat', 'reg')
par.file_regressor = e.getSerie('run_SimpleMotor2').getStim('reg').toJob(1);

par.file_reg = '^s5wts_.*nii';
par.rp       = 1;
par.rp_regex = '^multiple_regressors.txt';

% Masking
par.mask_thr = 0.1; % spm default option
par.mask     =  {}; % cell(char) of the path for the mask of EACH model : N models means N paths

par.sge      = 0;
par.run      = 1;
par.display  = 0;
par.redo     = 0;

par.TR = 1.660;

job_first_level_specify(dirFunc,dirStats,onsets,par);
e.addModel('glm',model_name,model_name);
mdl = e.getModel(model_name);
fspm = mdl.getPath();


%%

clear par
par.write_residuals = 0;

par.jobname  = 'spm_glm_est';
par.walltime = '11:00:00';

par.sge      = 0;
par.run      = 1;
par.display  = 0;
par.redo     = 0;

job_first_level_estimate(fspm, par);


%%

clear par
par.sessrep         = 'none';
par.report          = 0;

par.jobname         ='spm_glm_con';
par.walltime        = '04:00:00';

par.sge             = 0;
par.run             = 1;
par.display         = 0;
par.delete_previous = 1;


instr_rest   = [1 0 0 0];
instr_action = [0 1 0 0];
block_rest   = [0 0 1 0];
reg_action   = [0 0 0 1];

contrast_T.values = {
    
instr_rest
instr_action
block_rest
reg_action

reg_action - block_rest

}';

contrast_T.names = {

'instr_rest'
'instr_action'
'block_rest'
'reg_action'

'reg_action - block_rest'

}';


contrast_T.types = cat(1,repmat({'T'},[1 length(contrast_T.names)]));

contrast_F.names  = {'F-all'};
contrast_F.values = {eye(4)};
contrast_F.types  = cat(1,repmat({'F'},[1 length(contrast_F.names)]));

contrast.names  = [contrast_F.names  contrast_T.names ];
contrast.values = [contrast_F.values contrast_T.values];
contrast.types  = [contrast_F.types  contrast_T.types ];

job_first_level_contrast(fspm,contrast,par);

%%

mdl.show()
