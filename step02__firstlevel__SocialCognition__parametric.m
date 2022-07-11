clear
clc

load e

model_name = 'SocialCognition_event';

dirStats = e.mkdir('glm',model_name);
dirFunc  = get_parent_path( e.getSerie('run_SocialCognition').getVolume('s5wts').toJob() );
dirFunc   = cellfun(@cellstr, dirFunc, 'UniformOutput', 0);

onsetspath = '/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/ECODYST/onsets';
e.getSerie('run_SocialCognition').addStim(onsetspath, 'SocialCognition_run01_SPM_event.mat', model_name)
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


intention__Instruction   = [1 0 0  0 0 0  0 0 0  0 0 0  0];
intention__Presentation  = [0 1 0  0 0 0  0 0 0  0 0 0  0];
intention__Answer        = [0 0 1  0 0 0  0 0 0  0 0 0  0];
emotion__Instruction     = [0 0 0  1 0 0  0 0 0  0 0 0  0];
emotion__Presentation    = [0 0 0  0 1 0  0 0 0  0 0 0  0];
emotion__Answer          = [0 0 0  0 0 1  0 0 0  0 0 0  0];
physical_1__Instruction  = [0 0 0  0 0 0  1 0 0  0 0 0  0];
physical_1__Presentation = [0 0 0  0 0 0  0 1 0  0 0 0  0];
physical_1__Answer       = [0 0 0  0 0 0  0 0 1  0 0 0  0];
physical_2__Instruction  = [0 0 0  0 0 0  0 0 0  1 0 0  0];
physical_2__Presentation = [0 0 0  0 0 0  0 0 0  0 1 0  0];
physical_2__Answer       = [0 0 0  0 0 0  0 0 0  0 0 1  0];
Click                    = [0 0 0  0 0 0  0 0 0  0 0 0  1];

contrast_T.values = {
    
intention__Instruction
intention__Answer
emotion__Instruction
emotion__Presentation
emotion__Answer
physical_1__Instruction
physical_1__Presentation
physical_1__Answer
physical_2__Instruction
physical_2__Presentation
physical_2__Answer
Click

3*intention__Answer - (emotion__Answer   + physical_1__Answer + physical_2__Answer)
3*emotion__Answer   - (intention__Answer + physical_1__Answer + physical_2__Answer)
(physical_1__Answer + physical_2__Answer) - (emotion__Answer + intention__Answer)

}';

contrast_T.names = {
    
'intention__Instruction'
'intention__Answer'
'emotion__Instruction'
'emotion__Presentation'
'emotion__Answer'
'physical_1__Instruction'
'physical_1__Presentation'
'physical_1__Answer'
'physical_2__Instruction'
'physical_2__Presentation'
'physical_2__Answer'
'Click'

'INTENTION_Answer'
'EMOTION_Answer'
'PHYSICAL_Answer'

}';


contrast_T.types = cat(1,repmat({'T'},[1 length(contrast_T.names)]));

contrast_F.names  = {'F-all'};
contrast_F.values = {eye(13)};
contrast_F.types  = cat(1,repmat({'F'},[1 length(contrast_F.names)]));

contrast.names  = [contrast_F.names  contrast_T.names ];
contrast.values = [contrast_F.values contrast_T.values];
contrast.types  = [contrast_F.types  contrast_T.types ];

job_first_level_contrast(fspm,contrast,par);


%%

% mdl.show()
