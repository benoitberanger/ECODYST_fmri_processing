%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%   MULTI - ECHO    %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear

addpath('MB')

main_dir = '/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/ECODYST/nifti';


%% local or cluster ?

global_parameters.run = 1;
global_parameters.sge = 0;


%% Build exam lists

e = exam(main_dir, 'ECODYST_\w{2}_\d{2,3}_S{1,2}'); % all subjects with multi-echo

% seperate S1 and S2
e_S1 = e.getExam('S1$');
e_S2 = e.getExam('S2$');


%% SPECIAL : copy T1 from S2 to S1
% the rest  of the script is much easier this way

% add T1 from S2
e_S2.addSerie('T1w$', 'anat_T1', 1 );
e_S2.getSerie('anat').addVolume('^v_.*nii','v',1);

% Copy T1 from S2 to S1
src = e_S2.getSerie('anat').getVolume('^v').getPath();
fname = spm_file(src,'filename');
dst_dir = e_S1.mkdir('T1w');
dst = fullfile(dst_dir, fname);
r_movefile(src, dst, 'copyn');


%% EXEPTIONS

e_missing_MetalRotation = e.getExam('2023_03_28_ECODYST_RN_09_S1');
e_S1 = e_S1 - e_missing_MetalRotation;


%% Get files paths #matvol

%--------------------------------------------------------------------------
% S1

% Anat
e_S1.addSerie('T1w$', 'anat_T1', 1 );
e_S1.getSerie('anat').addVolume('^v_.*nii','v',1);

run_list = {'MentalRotation', 'SocialCognition', 'NBack', 'Fluency', 'SimpleMotor'};

for r = 1 : length(run_list)
    run_name = run_list{r};
    e_S1.addSerie([run_name           '$'], ['run_' run_name], 1);
    e_S1.addSerie([run_name '_PhysioLog$'], ['phy_' run_name], 1);
end


% distortion correction : use SBRef
for r = 1 : length(run_list)
    run_name = run_list{r};
    e_S1.addSerie([run_name       '_SBRef$'], ['sbref_' run_name '_forward'], 1);
    e_S1.addSerie([run_name '_revPE_SBRef$'], ['sbref_' run_name '_reverse'], 1);
end


%--------------------------------------------------------------------------
% EXCEPTIONS

% Anat
e_missing_MetalRotation.addSerie('T1w$', 'anat_T1', 1 );
e_missing_MetalRotation.getSerie('anat').addVolume('^v_.*nii','v',1);

run_list = {'SocialCognition', 'NBack', 'Fluency', 'SimpleMotor'};

for r = 1 : length(run_list)
    run_name = run_list{r};
    e_missing_MetalRotation.addSerie([run_name           '$'], ['run_' run_name], 1);
    e_missing_MetalRotation.addSerie([run_name '_PhysioLog$'], ['phy_' run_name], 1);
end


% distortion correction : use SBRef
for r = 1 : length(run_list)
    run_name = run_list{r};
    e_missing_MetalRotation.addSerie([run_name       '_SBRef$'], ['sbref_' run_name '_forward'], 1);
    e_missing_MetalRotation.addSerie([run_name '_revPE_SBRef$'], ['sbref_' run_name '_reverse'], 1);
end

%--------------------------------------------------------------------------
% S2

run_list = {'Emotion'};

for r = 1 : length(run_list)
    run_name = run_list{r};
    e_S2.addSerie([run_name           '$'], ['run_' run_name], 1);
    e_S2.addSerie([run_name '_PhysioLog$'], ['phy_' run_name], 1);
end


% distortion correction : use SBRef
for r = 1 : length(run_list)
    run_name = run_list{r};
    e_S2.addSerie([run_name       '_SBRef$'], ['sbref_' run_name '_forward'], 1);
    e_S2.addSerie([run_name '_revPE_SBRef$'], ['sbref_' run_name '_reverse'], 1);
end


%--------------------------------------------------------------------------
% Both

e.getSerie('run').addVolume('^v_.*nii$',   'v', 3);
e.getSerie('phy').addPhysio(     'dcm$', 'dcm', 1);
e.getSerie('sbref').addVolume('^v_.*e1.nii$', 'v', 1);


%% check if all echos have the same number of volumes #MATLAB/matvol
% this step takes time the first time you run it, but after its neglectable

e.getSerie('run').getVolume('v').removeEmpty().check_multiecho_Nvol()


%% segement T1 #MATLAB/SPM::CAT12

anat = e.gser('anat_T1').gvol('^v');
job_do_segmentCAT12(anat,global_parameters);


%% Sort echos #MATLAB/matvol

cfg = struct;
cfg.run  = 1;
cfg.fake = 0;
cfg.sge  = 0;
cfg.redo = 0;

meinfo = job_sort_echos( e.getSerie('run') , cfg );


%% minimal preprocessing for multi-echo #bash/ANFI::afni_proc.py

cfg = global_parameters;
cfg.blocks  = {'tshift', 'volreg', 'blip'};
afni_prefix = char(cfg.blocks); % {'tshift', 'volreg', 'blip'}
afni_prefix = afni_prefix(:,1)';
afni_prefix = fliplr(afni_prefix); % 'bvt'
afni_subdir = ['afni_' afni_prefix];
cfg.subdir = afni_subdir;

cfg.blip.forward = e.getSerie('sbref_.*_forward').getVolume();
cfg.blip.reverse = e.getSerie('sbref_.*_reverse').getVolume();
job_afni_proc_multi_echo( meinfo, cfg );


%% mask EPI #bash/FSL

 fin  = e.getSerie('run').getVolume(['^' afni_prefix 'e1']);
do_fsl_robust_mask_epi( fin, global_parameters );

% Checkpoint & unzip
cfg = global_parameters;
cfg.jobname = 'unzip_and_keep__bet';
e.getSerie('run').getVolume(['^bet_Tmean_' afni_prefix 'e1$']).removeEmpty().unzip_and_keep(cfg)


%% echo combination #python/TEDANA

tedana_subdir = ['tedana0011_' afni_prefix];
job_tedana_0011( meinfo, afni_prefix, tedana_subdir, ['bet_Tmean_' afni_prefix 'e1_mask.nii.gz'], global_parameters );

% Checkpoint & unzip
cfg = global_parameters;
cfg.jobname = 'unzip_and_keep__tedana';
e.getSerie('run').getVolume('^(ts_OC)|(^dn_ts_OC)').removeEmpty().unzip_and_keep(cfg)


%% coregister EPI to anat #MATLAB/SPM12

cfg = global_parameters;
cfg.type  = 'estimate';

src = e.getSerie('run').removeEmpty().getVolume(['^bet_Tmean_' afni_prefix 'e1$']);
oth = e.getSerie('run').removeEmpty().getVolume('(^ts_OC)|(^dn_ts_OC)');
ref = e.getSerie('run').removeEmpty().getExam.getSerie('anat_T1').getVolume('^p0');

cfg.jobname = 'spm_coreg_epi2anat';
job_coregister(src,ref,oth,cfg);


%% normalize EPI to MNI space #MATLAB/SPM12

img4D = e.getSerie('run').getVolume('(^ts_OC)|(^dn_ts_OC)'           ).removeEmpty();
img3D = e.getSerie('run').getVolume(['^bet_Tmean_' afni_prefix 'e1$']).removeEmpty();

img = img4D + img3D;
y   = img.getExam.getSerie('anat_T1').getVolume('^y');
cfg = global_parameters;
if global_parameters.sge % for cluster all jobs preparation, we need to give the voxel size
    % !!! this assumes all runs have the same resolution !!!
    % fetch resolution from the first volume
    V = e.getSerie('run').getVolume('^v');
    V = spm_vol(deblank(V(1).path(1,:)));
    cfg.vox = sqrt(sum(V(1).mat(1:3,1:3).^2));
end
job_apply_normalize(y,img,cfg);


%% smooth EPI #MATLAB/SPM12

cfg = global_parameters;
img = e.getSerie('run').getVolume('^w.*_OC').removeEmpty();

cfg.smooth   = [5 5 5];
cfg.prefix   = 's5';
cfg.jobname  = 'spm_smooth5';
job_smooth(img,cfg);

cfg.smooth   = [8 8 8];
cfg.prefix   = 's8';
cfg.jobname  = 'spm_smooth8';
job_smooth(img,cfg);


%% coregister WM & CSF on functionnal (using the warped mean) #SPM12
% This will be used for TAPAS:PhysIO

cfg = global_parameters;
ref = e.getSerie('run');
ref = ref(:,1).getVolume(['wbet_Tmean_' afni_prefix 'e1']);
src = e.getSerie('anat_T1').getVolume('^wp2');
oth = e.getSerie('anat_T1').getVolume('^wp3');
cfg.type = 'estimate_and_write';
cfg.jobname = 'spm_coreg_WMCSF2wEPI';
job_coregister(src,ref,oth,cfg);


%% rp afni2spm #matlab/matvol

% input
dfile = e.getSerie('run').getRP('rp_afni').removeEmpty();

% output
output_dir = fullfile( dfile.getSerie().getPath(), tedana_subdir );

% go
job_rp_afni2spm(dfile, output_dir);


%% extract physio from special dicom

% https://github.com/CMRR-C2P/MB

e.getSerie('phy').getPhysio('dcm').extract()

% e.getSerie('phy').getPhysio('phy').check() % takes a bit of time, use it once to verify your data


%% PhysIO nuisance regressor generation #matlab/TAPAS-PhysIO
%% Prepare files

% get physio files & check if some are missing
info = e.getSerie('phy').removeEmpty().getPhysio('info');   info = info(:);   missing_info = cellfun( 'isempty', info(:).getPath() );
puls = e.getSerie('phy').removeEmpty().getPhysio('puls');   puls = puls(:);   missing_puls = cellfun( 'isempty', puls(:).getPath() );
resp = e.getSerie('phy').removeEmpty().getPhysio('resp');   resp = resp(:);   missing_resp = cellfun( 'isempty', resp(:).getPath() );

run_all = e.getSerie('run').removeEmpty();

idx_missing = missing_info | missing_puls | missing_resp;
if ~any(idx_missing) % only good complete data
    idx_missing = logical(size(missing_info));
end

idx_ok = ~idx_missing;

run_phy_missing = run_all( idx_missing );
run_phy_ok      = run_all( idx_ok );

volume_phy_ok = run_phy_ok.getVolume('^wts_OC');
outdir_phy_ok = volume_phy_ok.getDir();
rp_phy_ok     = run_phy_ok.getRP('rp_spm');
mask_phy_ok   = run_phy_ok.getExam().getSerie('anat').getVolume('^rwp[23]');
info_ok       = info( idx_ok );
puls_ok       = puls( idx_ok );
resp_ok       = resp( idx_ok );

volume_phy_missing = run_phy_missing.getVolume('^wts_OC');
outdir_phy_missing = volume_phy_missing.getDir();
rp_phy_missing     = run_phy_missing.getRP('rp_spm');
mask_phy_missing   = run_phy_missing.getExam().getSerie('anat').getVolume('^rwp[23]').squeeze();


%% Prepare job : common

cfg = global_parameters;

cfg.TR     = 1.660;
cfg.nSlice = 60;

cfg.noiseROI_thresholds   = [0.95 0.80];     % keep voxels with tissu probabilty >= 95%
cfg.noiseROI_n_voxel_crop = [2 1];           % crop n voxels in each direction, to avoid partial volume
cfg.noiseROI_n_components = 10;              % keep n PCA componenets

cfg.rp_threshold = 1.0;  % Threshold above which a stick regressor is created for corresponding volume of exceeding value

cfg.print_figures = 0; % 0 , 1 , 2 , 3

cfg.rp_order     = 24;   % can be 6, 12, 24
% 6 = just add rp, 12 = also adds first order derivatives, 24 = also adds first + second order derivatives
cfg.rp_method    = 'FD'; % 'MAXVAL' / 'FD' / 'DVARS'

cfg.display  = 0;
cfg.redo     = 1;
cfg.walltime = '04:00:00';
cfg.mem      = '4G';


%% Prepare job : ok

% ALWAYS MANDATORY
cfg.physio   = 1;
cfg.noiseROI = 1;
cfg.rp       = 1;
cfg.volume = volume_phy_ok;
cfg.outdir = outdir_phy_ok;

% Physio
cfg.physio_Info = info_ok;
cfg.physio_PULS = puls_ok;
cfg.physio_RESP = resp_ok;
cfg.physio_RETROICOR        = 1;
cfg.physio_HRV              = 1;
cfg.physio_RVT              = 1;
cfg.physio_logfiles_vendor  = 'Siemens_Tics'; % Siemens CMRR multiband sequence, only this one is coded yet
cfg.physio_logfiles_align_scan = 'last';         % 'last' / 'first'
% Determines which scan shall be aligned to which part of the logfile.
% Typically, aligning the last scan to the end of the logfile is beneficial, since start of logfile and scans might be shifted due to pre-scans;
cfg.physio_slice_to_realign    = 'middle';       % 'first' / 'middle' / 'last' / sliceNumber (integer)
% Slice to which regressors are temporally aligned. Typically the slice where your most important activation is expected.

% noiseROI
cfg.noiseROI_mask   = mask_phy_ok;
cfg.noiseROI_volume = volume_phy_ok;

% Realignment Parameters
cfg.rp_file = rp_phy_ok;


cfg.jobname  = 'spm_physio_ok';
job_physio_tapas( cfg );


%% Prepare job : missing

% ALWAYS MANDATORY
cfg.physio   = 0; % !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
cfg.noiseROI = 1;
cfg.rp       = 1;
cfg.volume = volume_phy_missing;
cfg.outdir = outdir_phy_missing;

% Physio
cfg.physio_Info = [];
cfg.physio_PULS = [];
cfg.physio_RESP = [];
cfg.physio_RETROICOR = 0;
cfg.physio_HRV       = 0;
cfg.physio_RVT       = 0;

% noiseROI
cfg.noiseROI_mask   = mask_phy_missing;
cfg.noiseROI_volume = volume_phy_missing;

% Realignment Parameters
cfg.rp_file = rp_phy_missing;

cfg.jobname  = 'spm_physio_missing';
job_physio_tapas( cfg );


%% END

save e.mat e
