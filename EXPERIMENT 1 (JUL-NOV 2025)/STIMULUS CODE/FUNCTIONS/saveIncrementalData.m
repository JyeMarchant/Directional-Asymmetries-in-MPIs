function saveIncrementalData(csv_data, sbjname, currentBlock, totalBlocks, experimentType)
    % Save incremental CSV data after each block to prevent data loss
    % Only saves if experiment is not completed (for early termination protection)
    %
    % Inputs:
    %   csv_data - matrix containing experimental data
    %   sbjname - subject name/ID string
    %   currentBlock - current block number
    %   totalBlocks - total number of blocks in experiment
    %   experimentType - 'R' for radial, 'O' for orthogonal
    
    % Create the data save path
    savePath = '../data/';
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end
    
    % Get current date and time for filename
    time = clock;  % Returns [year month day hour minute second]
    
    % Create incremental filename with block information
    csv_filename = sprintf('%s_FGE_%s_%02g_%02g_%02g_%02g_%02g_block%d_of_%d.csv', ...
        sbjname, experimentType, time(1), time(2), time(3), time(4), time(5), currentBlock, totalBlocks);
    csv_filepath = [savePath, csv_filename];
    
    % Convert data to table for CSV output with meaningful column names
    csv_table = table(csv_data(:,1), csv_data(:,2), csv_data(:,3), csv_data(:,4), csv_data(:,5), csv_data(:,6), ...
        csv_data(:,7), csv_data(:,8), csv_data(:,9), csv_data(:,10), csv_data(:,11), csv_data(:,12), csv_data(:,13), ...
        csv_data(:,14), csv_data(:,15), csv_data(:,16), ...
        'VariableNames', {'block', 'trial_number', 'valid_trial', 'staircase_trial', 'motion_direction', ...
        'quadrant', 'eccentricity', 'jitter_dva', 'flash_dva', 'flash_seconds', 'response', 'probe_offset_dva', ...
        'staircase_identity', 'step_size_dva', 'staircase_direction', 'staircase_reversals'});
    
    % Write incremental CSV file
    writetable(csv_table, csv_filepath);
    fprintf('Incremental data saved after block %d: %s\n', currentBlock, csv_filepath);
end