clear
clc

load e

model_name = 'SocialCognition_block';

dirStats = e.mkdir('glm',model_name);
dirFunc  = get_parent_path( e.getSerie('run_SocialCognition').getVolume('s5wts').toJob() );
dirFunc   = cellfun(@cellstr, dirFunc, 'UniformOutput', 0);

onsetspath = '/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/ECODYST/onsets';
e.getSerie('run_MentalRotation').addStim(onsetspath, 'SocialCognition_run01_SPM_block.mat', model_name)
onsets = e.getSerie('run').getStim(model_name).toJob(0);

clear par
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


intention  = [1 0 0 0 0];
emotion    = [0 1 0 0 0];
physical_1 = [0 0 1 0 0];
physical_2 = [0 0 0 1 0];
Click      = [0 0 0 0 1];

contrast_T.values = {
    
intention
emotion
physical_1
physical_2
Click

3*intention - (emotion   + physical_1 + physical_2)
3*emotion   - (intention + physical_1 + physical_2)
(physical_1 + physical_2) - (emotion + intention)

}';

contrast_T.names = {
    
'intention'
'emotion'
'physical_1'
'physical_2'
'Click'

'INTENTION'
'EMOTION'
'PHYSICAL'

}';


contrast_T.types = cat(1,repmat({'T'},[1 length(contrast_T.names)]));

contrast_F.names  = {'F-all'};
contrast_F.values = {eye(5)};
contrast_F.types  = cat(1,repmat({'F'},[1 length(contrast_F.names)]));

contrast.names  = [contrast_F.names  contrast_T.names ];
contrast.values = [contrast_F.values contrast_T.values];
contrast.types  = [contrast_F.types  contrast_T.types ];

job_first_level_contrast(fspm,contrast,par);

%%

% mdl.show()
