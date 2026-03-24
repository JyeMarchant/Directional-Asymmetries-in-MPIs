function cleanupIncrementalFiles(sbjname, experimentType)
    % Clean up incremental save files after successful experiment completion
    % 
    % Inputs:
    %   sbjname - subject name/ID string
    %   experimentType - 'R' for radial, 'O' for orthogonal
    
    % Create the data save path
    savePath = '../data/';
    
    % Find and delete incremental save files for this subject and experiment type
    search_pattern = sprintf('%s_FGE_%s_*_block*_of_*.csv', sbjname, experimentType);
    incremental_files = dir(fullfile(savePath, search_pattern));
    
    if ~isempty(incremental_files)
        fprintf('Cleaning up %d incremental save files...\n', length(incremental_files));
        for i = 1:length(incremental_files)
            file_path = fullfile(savePath, incremental_files(i).name);
            delete(file_path);
            fprintf('Deleted: %s\n', incremental_files(i).name);
        end
    end
end