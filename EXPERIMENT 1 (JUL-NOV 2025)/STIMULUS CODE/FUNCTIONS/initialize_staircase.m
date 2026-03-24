function staircase = initialize_staircase(start, step, minimumStepSize)
    staircase.stimuluslevel = start;
    staircase.step = step;
    staircase.minimumStepSize = minimumStepSize;
    staircase.reversals = 0;
    staircase.direction = NaN;  % Will be set on first trial
    staircase.progression = start;  % Initialize with starting value
    staircase.actualOffsets = [];
    staircase.lastResponse = NaN;  % ADD THIS: Track each staircase's last response
end