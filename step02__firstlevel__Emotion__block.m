clear
clc

load e

model_name = 'Emotion_block';

dirStats = e.mkdir('glm',model_name);
dirFunc  = get_parent_path( e.getSerie('run_Emotion').getVolume('s5wts').toJob() );
dirFunc   = cellfun(@cellstr, dirFunc, 'UniformOutput', 0);

onsetspath = '/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/ECODYST/onsets';
e.getSerie('run_Emotion').addStim(onsetspath, 'Emotion_run0\d_SPM_block.mat$', model_name)
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


regressor_order = {
    'relax'  1
    'stress' 1
    'relax'  2
    'stress' 2
    };
names = {};
for o = 1: size(regressor_order,1)
    type = regressor_order{o,1};
    num  = regressor_order{o,2};
    names{end+1,1} = sprintf('%s_%d__baseline_instruction', type, num);
    names{end+1,1} = sprintf('%s_%d__baseline_rest'       , type, num);
    names{end+1,1} = sprintf('%s_%d__script_instruction'  , type, num);
    names{end+1,1} = sprintf('%s_%d__script_playback'     , type, num);
    names{end+1,1} = sprintf('%s_%d__postscript'          , type, num);
    names{end+1,1} = sprintf('%s_%d__recovery_instruction', type, num);
    names{end+1,1} = sprintf('%s_%d__recovery_rest'       , type, num);
    names{end+1,1} = sprintf('%s_%d__likert_immersion'    , type, num);
    names{end+1,1} = sprintf('%s_%d__likert_anxiety'      , type, num);
end
N = length(names);
r = struct;
for n = 1 : N
    vect = zeros(1,N);
    vect(n) = 1;
    r.(names{n}) = vect;
end


contrast_T.values = {

r.relax_1__likert_anxiety + r.relax_1__likert_immersion  +  r.relax_2__likert_anxiety + r.relax_2__likert_immersion  +  r.stress_1__likert_anxiety + r.stress_1__likert_immersion  +  r.stress_2__likert_anxiety + r.stress_2__likert_immersion

(r.stress_1__script_playback + r.stress_2__script_playback) - (r.relax_1__script_playback + r.relax_2__script_playback)

}';

contrast_T.names = {
    
'likert'

'playback : stress - relax'

}';


contrast_T.types = cat(1,repmat({'T'},[1 length(contrast_T.names)]));

contrast_F.names  = {'F-all'};
contrast_F.values = {eye(N)};
contrast_F.types  = cat(1,repmat({'F'},[1 length(contrast_F.names)]));

contrast.names  = [contrast_F.names  contrast_T.names ];
contrast.values = [contrast_F.values contrast_T.values];
contrast.types  = [contrast_F.types  contrast_T.types ];

job_first_level_contrast(fspm,contrast,par);


%%

% mdl.show()
