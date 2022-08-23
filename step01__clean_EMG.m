%% Init

clear
clc

% addpath('/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/FARM_dev')
% addpath('/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/fieldtrip_dev')

assert( ~isempty(which('ft_preprocessing')), 'FieldTrip library not detected. Check your MATLAB paths, or get : https://github.com/fieldtrip/fieldtrip' )
assert( ~isempty(which('farm_rootdir'))    ,      'FARM library not detected. Check your MATLAB paths, or get : https://github.com/benoitberanger/FARM' )

% Initialize FieldTrip
ft_defaults


%% Sequence paramters

emg_channel_name = {
    'L_SCM'
    'L_DEL'
    'L_EXT'
    'L_IO1'
    'R_SCM'
    'R_DEL'
    'R_EXT'
    'R_IO1'
    };

emg_channel_regex = farm.cellstr2regex({
    'SCM'
    'DEL'
    'EXT'
    'IO1'
    });

MRI_trigger_message = 'R128';

sequence.TR     = 1.66; % in seconds
sequence.nSlice = 60;
sequence.MB     = 3;   % multiband factor
sequence.nVol   = [];  % integer or NaN, if [] it means use all volumes
% Side note : if the fMRI sequence has been manually stopped, the last volume will probably be incomplete.
% But this incomplete volume will stil generate a marker. In this case, you need to define sequence.nVol or use farm_remove_last_volume_event()
disp(sequence)

ACC_bandwidth = [0.1   10];


%% Protocol paramters

main_dir = '/network/lustre/iss02/cenir/analyse/irm/users/benoit.beranger/ECODYST';

subj_dir = gdir(main_dir, 'onsets', 'ECODYST');
hdr_file = gfile(subj_dir, '.*vhdr');

for iSubj = 1 : length(hdr_file)
    for iRun = 1 : size(hdr_file{iSubj},1)
        
        
        fprintf('# FARM : %d / %d \n', iSubj, iRun)
        
        fname_hdr = deblank(hdr_file{iSubj}(iRun,:));
        fname_mrk = spm_file(fname_hdr, 'ext','.vmrk');
        fname_eeg  = spm_file(fname_hdr, 'ext','.eeg' );
        
        % Read header & events
        cfg           = [];
        cfg.dataset   = fname_hdr;
        raw_event     = ft_read_event (fname_mrk);
        event         = farm_change_marker_value(raw_event, MRI_trigger_message, 'V'); % rename volume marker, just for comfort
        event         = farm_delete_marker(event, 'Sync On');                          % not useful for FARM, this marker comes from the clock synchronization device
        
        % Load data
        data                    = ft_preprocessing(cfg); % load data
        data.cfg.event          = event;                 % store events
        data.sequence           = sequence;              % store sequence parameters
        data.volume_marker_name = 'V';                   % name of the volume event in data.cfg.event
        
        % Some paramters tuning
        data.cfg.intermediate_results_overwrite = false; % don't overwrite files
        data.cfg.intermediate_results_save      = true;  % write on disk intermediate results
        data.cfg.intermediate_results_load      = true;  % if intermediate result file is detected, to not re-do step and load file
        
        
        %% FARM main workflow is wrapped in this function:
        
        data = farm_main_workflow( data, emg_channel_regex );
        
        
        %% Save final results for faster loading
        
        farm_export_mat( data ) % MATLAB ( .mat )
        
        
        %% Print figures
        
        figH = farm_plot_FFT(data, emg_channel_regex,       'raw', [30 250]   );  farm_print_figure( data, figH ); close(figH);
        figH = farm_plot_FFT(data, emg_channel_regex, 'pca_clean', [30 250]   );  farm_print_figure( data, figH ); close(figH);
        
        figH = farm_plot_FFT(data,         'ACC',       'raw', ACC_bandwidth, 2); farm_print_figure( data, figH ); close(figH);
        
        
        %% Generate regressors
        
        for chan = 1 : length(emg_channel_name)
            ts      = farm_get_timeseries( data, emg_channel_name{chan}, 'pca_clean', +[30 250] ); % (2 x nSamples)
            reginfo = farm_emg_regressor ( data, ts, emg_channel_name{chan} );
            farm_save_regressor( data, reginfo)
        end
        
        
        %% Time-Frequency Analysis
        
        cfg_TFA = [];
        cfg_TFA.emg_regex = emg_channel_regex;
        cfg_TFA.acc_regex = 'ACC';
        cfg_TFA.foi       = ACC_bandwidth;
        TFA = farm_time_frequency_analysis_emg_acc( data, cfg_TFA );
        figH = farm_plot_TFA( data, TFA ); farm_print_figure( data, figH ); close(figH);
        
        
        %% Coherence Analysis
        
        cfg_coh = [];
        cfg_coh.emg_regex = emg_channel_regex;
        cfg_coh.acc_regex = 'ACC';
        cfg_coh.foi    = ACC_bandwidth;
        cfg_coh.foi = ACC_bandwidth;
        coh = farm_coherence_analysis_emg_acc( data, cfg_coh );
        figH = farm_plot_coherence( data, coh, cfg_coh ); farm_print_figure( data, figH ); close(figH);
        
        side = {'L', 'R'};
        
        for s = side
            %% Select best EMG channel, that matches ACC using coherence
            
            LR = char(s);
            
            cfg_select_emg = [];
            cfg_select_emg.emg_regex = sprintf('%s_%s',LR,emg_channel_regex);
            cfg_select_emg.acc_regex = sprintf('%s_ACC' ,LR                  );
            cfg_select_emg.foi       = ACC_bandwidth;
            best_emg = farm_select_best_emg_using_acc_coherence( data, cfg_select_emg );
            
            
            %% Generate regressors
            
            reginfo      = farm_make_regressor( data, best_emg.peakpower, best_emg.fsample);
            reginfo.name = ['peakpower@bestemg==' best_emg.label];
            figH         = farm_plot_regressor( data, reginfo ); farm_print_figure( data, figH ); close(figH);
            farm_save_regressor(data, reginfo)
            
            
            %% Accelerometer : this regressor will be a backup in case of bad EMG
            
            acc          = farm_get_timeseries(data,sprintf('%s_ACC' ,LR),'raw', [2 8],2);
            reginfo      = farm_acc_regressor(data, acc);
            reginfo.name = sprintf('euclidiannorm@ACCXYZ_%s' ,LR);
            figH         = farm_plot_regressor( data, reginfo ); farm_print_figure( data, figH ); close(figH);
            farm_save_regressor(data, reginfo)
            
            
        end % side LR
        
    end % iSubj
end % iSubj
