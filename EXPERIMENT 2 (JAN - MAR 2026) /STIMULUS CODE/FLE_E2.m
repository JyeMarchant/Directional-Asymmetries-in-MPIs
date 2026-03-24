%========================================================================================
%%                      FLASH-LAG EFFECT BASELINE EXPERIMENT
%                              Experiment 2 (E2)
%                      Last modified: Feb 04, 2026 
% ========================================================================================= 
%
%                         
%%                                DESCRIPTION:
%      Psychophysical experiment investigating baseline decomposition of the 
%      Flash-Lag Effect (FLE). Tests whether directional asymmetry in the FLE 
%      is explained by independent position biases for the flash and moving 
%      object, or by an interaction when they are spatially paired.
%
%
%%                         EXPERIMENTAL CONDITIONS:
%   
%   1. flashbaseline    - Flash alone, no motion → baseline flash bias
%   2. centralcue       - Moving bar with central cue (no flash) → baseline motion bias  
%   3. flash_motion     - Localize FLASH with moving bar present
%   4. motion_flash     - Localize MOVING BAR with flash present (classic FLE)
%
%   Block order is counterbalanced across participants using Latin square.
%
% RESPONSE:
%   Method of Adjustment - Use mouse to adjust probe to target location
%
% IMPORTANT: Configure monitor to 85Hz and 800x600 resolution before running.
%
%==========================================================================================

clear all; close all;

%% EXPERIMENT SETUP

%----------------------------------------------------------------------
%%                   TRIAL AND BLOCK SETTINGS
%----------------------------------------------------------------------
% 
% COUNTERBALANCING LOGIC:
% -----------------------
% For ALL conditions, we counterbalance:
%   - 4 quadrants (45°, 135°, 225°, 315°)
%   - 2 eccentricities (7 DVA, 11 DVA)
%
% For MOTION conditions (centralcue, flash_motion, motion_flash):
%   - Additionally: 2 motion directions (petal = inward, fugal = outward)
%   - Total: 4 quadrants × 2 eccentricities × 2 directions = 16 combinations
%   - MINIMUM: 16 trials per block for full counterbalancing
%
% For FLASH BASELINE condition:
%   - No motion direction factor
%   - Total: 4 quadrants × 2 eccentricities = 8 combinations
%   - MINIMUM: 8 trials per block for full counterbalancing (use 16 for
%   measure)
%
% Additional factors (randomly assigned, not counterbalanced):
%   - Flash side (left/right of trajectory - recorded as upper/lower in CSV) 
%   - FLash Jitter( -1, 0, +1 DVA)
%   - Probe begins at fixation 50% of trials, for the rest randomly in a
%   quadrant at 16dva (**?**) 
%
%  RECOMMENDED: Use multiples of 16 for numTrialsPerBlock (16, 32, 48...)
%  to ensure equal representation of all counter balanced factors
%               across all conditions .
%-----------------------------------------------------------------------

exp.version = 'E2_v02022025';
sbjname = '029'; 
numTrialsPerBlock = 32;
numBlocks = 12;
isEyelink = 1; 

%----------------------------------------------------------------------
%%                     PSYCHTOOLBOX INITIALIZATION 
%----------------------------------------------------------------------

Screen('Preference', 'SkipSyncTests', 1);  
Screen('Preference', 'VBLTimestampingMode', 1);  
Screen('Preference', 'ConserveVRAM', 0);  
KbName('UnifyKeyNames');
screens = Screen('Screens');
screenNumber = max(screens);

% Add function path
addpath(fullfile(fileparts(mfilename('fullpath')), 'FUNCTIONS'));

%----------------------------------------------------------------------
%%                         DISPLAY PARAMETERS
%----------------------------------------------------------------------
black = BlackIndex(screenNumber);       
white = WhiteIndex(screenNumber);       
grey = white / 2;    
red = [255 0 0];
softRed = [220 100 100];  % Softer, less harsh violation color                        

% Expected refresh rate
refreshRate = 85;

% MUTE macOS ALERT SOUNDS during experiment 
% Save current alert volume and set to 0
try
    [~, alertVolumeStr] = system('osascript -e "get alert volume of (get volume settings)"');
    originalAlertVolume = str2double(strtrim(alertVolumeStr));
    if isnan(originalAlertVolume)
        originalAlertVolume = 100;  % Default if parsing fails
    end
    system('osascript -e "set volume alert volume 0"');
catch
    originalAlertVolume = 100;  % Default if command fails
end

% Set specific screen resolution
Screen('Resolution', screenNumber, 800, 600); 
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Suppress keyboard input to MATLAB command window
ListenChar(-1);

% Hide cursor - use screen number for macOS compatibility
HideCursor(screenNumber);

% Confine mouse cursor to experiment window (prevents clicking outside)
% Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS

% Query actual frame rate
ifi = Screen('GetFlipInterval', window);
measuredRefreshRate = round(1/ifi);
assert(abs(measuredRefreshRate - refreshRate) <= 2, ...
    'Refresh rate mismatch: measured %d Hz, expected %d Hz', measuredRefreshRate, refreshRate);

% GPU optimizations
Priority(MaxPriority(window));  % Maximum CPU priority
Screen('BlendFunction', window, 'GL_ONE', 'GL_ZERO');  % Disable alpha blending for speed
topPriorityLevel = MaxPriority(window);

commandwindow;

eyeScreenDistance = 57;    
screenHeight = 29.4;       
screenHeightPixels = windowRect(4);  
xCenter = windowRect(3) / 2;  
yCenter = windowRect(4) / 2;  

% Quadrant angles
quadrants = [45 135 225 315];  

%% FIXATION CROSS
fixCrossDimDva = 0.5;
fixCrossDimPix = dva2pix(fixCrossDimDva, eyeScreenDistance, windowRect, screenHeight);
fixCoords = [-fixCrossDimPix fixCrossDimPix 0 0; 0 0 -fixCrossDimPix fixCrossDimPix];
fixLineWidth = 3;
fixDuration = 0.5;

%% CENTRAL CUE SETTINGS
% Cue type: 1 = fixation color change (cross turns red)
%           2 = red square at fixation (tilted to match peripheral flash)
centralCueType = 2;  % <-- CHANGE THIS TO SWITCH CUE TYPE
centralCueSizeDva = 0.5;  % Size of square cue (only used if cueType = 2)

%% MOVING BAR PARAMETERS (White bar)
bar.WidthDva = 0.5;   
bar.LengthDva = 3;    
bar.WidthPix = dva2pix(bar.WidthDva, eyeScreenDistance, windowRect, screenHeight);
bar.LengthPix = dva2pix(bar.LengthDva, eyeScreenDistance, windowRect, screenHeight);
bar.Size = [0, 0, bar.WidthPix, bar.LengthPix];
bar.HalfWidth = bar.WidthPix / 2;
bar.HalfLength = bar.LengthPix / 2;  

% Create white bar texture
bar.Image = ones(bar.LengthPix, bar.WidthPix, 3) * white;
bar.Texture = Screen('MakeTexture', window, bar.Image);

% Motion parameters
bar.speedDvaPerSec = 20;   % Speed in DVA per second - adjust this to change speed
bar.speedDvaPerFrame = bar.speedDvaPerSec / refreshRate;  % DVA per frame for theoretical calculations
bar.speedPixPerSec = dva2pix(bar.speedDvaPerSec, eyeScreenDistance, windowRect, screenHeight);
bar.speedPixPerFrame = bar.speedPixPerSec / refreshRate;  % Convert to pixels per frame
bar.startDistDva = 3;      % Start distance from center (DVA)
bar.endDistDva = 15;       % End distance from center (DVA)
bar.startDistPix = dva2pix(bar.startDistDva, eyeScreenDistance, windowRect, screenHeight);
bar.endDistPix = dva2pix(bar.endDistDva, eyeScreenDistance, windowRect, screenHeight);
bar.movDistPix = bar.endDistPix - bar.startDistPix;  % Total movement distance
bar.HalfWidthDva = bar.WidthDva / 2;  % 0.25 DVA - for theoretical target calculations

%% FLASH PARAMETERS (Red square, 0.5 x 0.5 DVA)
flash.SizeDva = 0.5;
flash.SizePix = dva2pix(flash.SizeDva, eyeScreenDistance, windowRect, screenHeight);
flash.Rect = [0, 0, flash.SizePix, flash.SizePix];
flash.GapFromBarDva = 0.5;  % Gap between bar edge and flash edge
flash.GapFromBarPix = dva2pix(flash.GapFromBarDva, eyeScreenDistance, windowRect, screenHeight);
flash.presentFrame = 4;  % Frames to present flash (~47ms at 85Hz)

% Pre-compute total perpendicular offset (half bar + gap + half flash)
flash.TotalOffsetPix = (bar.LengthPix/2) + flash.GapFromBarPix + (flash.SizePix/2);

% Create red flash texture
flash.Image = zeros(flash.SizePix, flash.SizePix, 3);
flash.Image(:,:,1) = white;  % Red channel only
flash.Texture = Screen('MakeTexture', window, flash.Image);

% Flash eccentricity
flash.EccentricityDva = [7, 11];  
flash.JitterDva = [-1, 0, 1];

% Pre-compute pixels per DVA for efficient runtime calculations
pixPerDva = dva2pix(1, eyeScreenDistance, windowRect, screenHeight);

% Pre-compute trigonometric constants (45 degrees is used throughout)
sin45 = sind(45);  % ≈ 0.7071
cos45 = cosd(45);  % ≈ 0.7071

% Pre-compute eccentricities in pixels
flash.EccentricityPix = flash.EccentricityDva * pixPerDva;
flash.JitterPix = flash.JitterDva * pixPerDva;

%% CENTRAL CUE TEXTURE (created here after pixPerDva is defined)
if centralCueType == 2
    centralCueSizePix = centralCueSizeDva * pixPerDva;
    centralCueRect = [0, 0, centralCueSizePix, centralCueSizePix];
    centralCueImage = zeros(round(centralCueSizePix), round(centralCueSizePix), 3);
    centralCueImage(:,:,1) = white;  % Red channel only
    centralCueTexture = Screen('MakeTexture', window, centralCueImage);
    % Pre-compute centered rect for cue (always at fixation)
    centralCueDestRect = CenterRectOnPoint(centralCueRect, xCenter, yCenter);
end

%% PROBE PARAMETERS (Gray square for flash, Gray bar for central cue)
probe.SizeDva = 0.5;
probe.SizePix = dva2pix(probe.SizeDva, eyeScreenDistance, windowRect, screenHeight);
probe.Rect = [0, 0, probe.SizePix, probe.SizePix];

% Create gray SQUARE probe texture (for flash localization)
probe.Image = ones(probe.SizePix, probe.SizePix, 3) * grey;
probe.Texture = Screen('MakeTexture', window, probe.Image);

% Create gray BAR probe texture (for central cue condition)
probe.BarWidthDva = 0.5;
probe.BarLengthDva = 3;
probe.BarWidthPix = dva2pix(probe.BarWidthDva, eyeScreenDistance, windowRect, screenHeight);
probe.BarLengthPix = dva2pix(probe.BarLengthDva, eyeScreenDistance, windowRect, screenHeight);
probe.BarRect = [0, 0, probe.BarWidthPix, probe.BarLengthPix];
probe.BarImage = ones(probe.BarLengthPix, probe.BarWidthPix, 3) * grey;
probe.BarTexture = Screen('MakeTexture', window, probe.BarImage);

probe.intervalTime = 0.5;
probe.intervalFrames = round(probe.intervalTime * refreshRate);

% Mouse-based probe start positions
probe.PeripheralStartDva = 16;  % Peripheral start at 16 DVA on diagonal
probe.PeripheralStartPix = dva2pix(probe.PeripheralStartDva, eyeScreenDistance, windowRect, screenHeight);

% Preload all textures to GPU
Screen('PreloadTextures', window);

%% GAZE MONITORING PARAMETERS
gazeMonitoringRadius_dva = 3;  
centerDiskRadiusPix = dva2pix(gazeMonitoringRadius_dva, eyeScreenDistance, windowRect, screenHeight);
gazeThresholdPix = centerDiskRadiusPix;  % Pre-computed threshold for gaze checks  

%----------------------------------------------------------------------
%%                   COUNTERBALANCE BLOCK ORDER
%----------------------------------------------------------------------

% Condition names for display
conditionNames = {'flashbaseline', 'centralcue', 'flash_motion', 'motion_flash'};
conditionInstructions = {
    ['A red square will flash briefly in your peripheral vision.\n\n' ...
     'Adjust the grey square to where the flash appeared,\n' ...
     'then click to confirm.'];
    
    ['A white bar will move diagonally across the screen.\n' ...
     'The fixation cross will briefly change to a red cue.\n\n' ...
     'Adjust the grey bar to where the bar was at the time of the cue,\n' ...
     'then click to confirm.'];
    
    ['A white bar will move AND a red square will flash.\n\n' ...
     'Adjust the grey square to where the flash appeared,\n' ...
     'then click to confirm.'];
    
    ['A white bar will move AND a red square will flash.\n\n' ...
     'Adjust the grey bar to where the bar was at the time of the flash,\n' ...
     'then click to confirm.']
};

% Get subject number as numeric
if ischar(sbjname) || isstring(sbjname)
    subjectNum = str2double(sbjname);
else
    subjectNum = sbjname;
end

% Get counterbalanced block order (Latin square - specific order per participant)
% Now supports any number of blocks (not just 8)
blockOrder = getCounterbalanceOrder(subjectNum, numBlocks);

%----------------------------------------------------------------------
%%                   GENERATE TRIAL STRUCTURE
%----------------------------------------------------------------------
% Creates balanced trial lists for each condition.
% 
% COUNTERBALANCING STRUCTURE:
% ---------------------------
% Flash Baseline (cond 1): 4 quadrants × 2 eccentricities = 8 combinations
%   - Each combination appears floor(numTrialsPerBlock/8) times
%   - Flash side and jitter are randomly assigned (not counterbalanced)
%
% Motion conditions (cond 2,3,4): 4 quadrants × 2 eccentricities × 2 directions = 16 combinations
%   - Each combination appears floor(numTrialsPerBlock/16) times
%   - Flash side and jitter are randomly assigned (not counterbalanced)
%
% With numTrialsPerBlock = 16: 1 trial per combination for motion (minimum)
%                              2 trials per combination for flash baseline
% With numTrialsPerBlock = 32: 2 trials per combination for motion
%                              4 trials per combination for flash baseline
%----------------------------------------------------------------------

all_trials = cell(4, 1);  % One cell per condition

for cond = 1:4
    trials = [];
    
    if cond == 1  % flashbaseline - no motion, but needs both petal AND fugal timing
        % Counterbalance: 4 quadrants × 2 eccentricities × 2 timing modes = 16 combinations
        % timingMode: -1 = petal timing, +1 = fugal timing (mimics when flash would appear)
        for q = 1:length(quadrants)
            for e = 1:length(flash.EccentricityDva)
                for timingMode = [-1, 1]  % petal timing (-1) and fugal timing (+1)
                    % Number of repetitions per combination
                    nReps = max(1, floor(numTrialsPerBlock / 16));
                    for r = 1:nReps
                        % [quadrant, timingMode, eccentricity, flashSide, jitter]
                        flashSide = (randi(2) * 2 - 3);  % Random -1 or 1
                        jitter = flash.JitterDva(randi(length(flash.JitterDva)));
                        trials = [trials; quadrants(q), timingMode, flash.EccentricityDva(e), flashSide, jitter];
                    end
                end
            end
        end
        % Shuffle trials
        trials = trials(randperm(size(trials, 1)), :);
        
    else  % Motion conditions (2, 3, 4)
        % Counterbalance: 4 quadrants × 2 eccentricities × 2 directions = 16 combinations
        for q = 1:length(quadrants)
            for e = 1:length(flash.EccentricityDva)
                for motDir = [-1, 1]  % petal (-1) and fugal (+1)
                    % Number of repetitions per quadrant-eccentricity-direction combination
                    nReps = max(1, floor(numTrialsPerBlock / 16));
                    for r = 1:nReps
                        flashSide = (randi(2) * 2 - 3);  % Random -1 or 1
                        jitter = flash.JitterDva(randi(length(flash.JitterDva)));
                        trials = [trials; quadrants(q), motDir, flash.EccentricityDva(e), flashSide, jitter];
                    end
                end
            end
        end
        % Shuffle trials
        trials = trials(randperm(size(trials, 1)), :);
    end
    
    all_trials{cond} = trials;
end

%----------------------------------------------------------------------
%%                   EYELINK SETUP
%----------------------------------------------------------------------

% Create data folder
data_folder = fullfile(fileparts(mfilename('fullpath')), '../E2 DATA');
if ~exist(data_folder, 'dir')
    mkdir(data_folder);
end

% EDF filename setup
subject_prefix = sbjname(1:min(3,length(sbjname)));
existing_files = dir(fullfile(data_folder, [subject_prefix, '*.edf']));
session_numbers = [];

for i = 1:length(existing_files)
    filename = existing_files(i).name;
    if length(filename) == 8 && strcmp(filename(end-3:end), '.edf')
        session_part = filename(4:5);
        if all(isstrprop(session_part, 'digit'))
            session_numbers = [session_numbers, str2double(session_part)];
        end
    end
end

if isempty(session_numbers)
    next_session = 1;
else
    next_session = max(session_numbers) + 1;
end

edf_name = sprintf('%s%02d', subject_prefix, next_session);
constants.eyelink_data_fname = [edf_name, '.edf'];
constants.eyelink_data_path = fullfile(data_folder, constants.eyelink_data_fname);

%----------------------------------------------------------------------
%%                       SOUND SETUP (must be BEFORE Eyelink for calibration beeps)
%----------------------------------------------------------------------
InitializePsychSound(1);
sampRate = 44100;
soundsFolder = fullfile(fileparts(mfilename('fullpath')), 'Sounds');

% Load error notification sound for gaze violations
errorSoundFile = fullfile(soundsFolder, 'error-notification.mp3');
[errorSound, errorFs] = audioread(errorSoundFile);
errorSound = errorSound';  % Transpose to row format for PsychPortAudio
if size(errorSound, 1) == 1
    errorSound = [errorSound; errorSound];  % Make stereo if mono
end
pahandle_warning = PsychPortAudio('Open', [], [], 0, errorFs, 2);
PsychPortAudio('FillBuffer', pahandle_warning, errorSound);

% Load success sounds for experiment completion
correctoFile = fullfile(soundsFolder, 'correcto-100-mexicanos-dijeron.mp3');
[correctoSound, correctoFs] = audioread(correctoFile);
correctoSound = correctoSound';  % Transpose to row format for PsychPortAudio
if size(correctoSound, 1) == 1
    correctoSound = [correctoSound; correctoSound];  % Make stereo if mono
end
pahandle_correcto = PsychPortAudio('Open', [], [], 0, correctoFs, 2);
PsychPortAudio('FillBuffer', pahandle_correcto, correctoSound);

woohooFile = fullfile(soundsFolder, 'homer-woohoo.mp3');
[woohooSound, woohooFs] = audioread(woohooFile);
woohooSound = woohooSound';  % Transpose to row format for PsychPortAudio
if size(woohooSound, 1) == 1
    woohooSound = [woohooSound; woohooSound];  % Make stereo if mono
end
pahandle_woohoo = PsychPortAudio('Open', [], [], 0, woohooFs, 2);
PsychPortAudio('FillBuffer', pahandle_woohoo, woohooSound);

% Load tick sound for response confirmation
tickFile = fullfile(soundsFolder, 'tick.mp3');
[tickSound, tickFs] = audioread(tickFile);
tickSound = tickSound';
if size(tickSound, 1) == 1
    tickSound = [tickSound; tickSound];
end
pahandle_tick = PsychPortAudio('Open', [], [], 0, tickFs, 2);
PsychPortAudio('FillBuffer', pahandle_tick, tickSound);

% Separate audio handle for Eyelink calibration sounds
pahandle_eyelink = PsychPortAudio('Open', [], [], 0, sampRate, 2);

% Initialize EyeLink
el = [];
eyeUsed = -1;
MISSING_DATA = -32768;

if isEyelink
    if EyelinkInit(0) ~= 1
        isEyelink = 0;
    else
        if Eyelink('OpenFile', constants.eyelink_data_fname) ~= 0
            Eyelink('Shutdown');
            isEyelink = 0;
        else
            el = EyelinkInitDefaults(window);
            el.calibrationtargetcolour = [255 255 255];
            el.calibrationtargetsize = 1.0;
            el.calibrationtargetwidth = 0.5;
            % Enable calibration beeps
            el.targetbeep = 1;
            el.feedbackbeep = 1;
            el.ppa_pahandle = pahandle_eyelink;  % Audio handle for calibration sounds
            Eyelink('command', 'calibration_area_proportion = 0.5 0.5');
            Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, windowRect(3)-1, windowRect(4)-1);
            Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
            Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
            Eyelink('Command', 'file_sample_data = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
            Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
            Eyelink('Command', 'set_idle_mode');
            Eyelink('Command', 'clear_screen 0');
            EyelinkUpdateDefaults(el);
            EyelinkDoTrackerSetup(el);
            Eyelink('Command', 'set_idle_mode');
        end
    end
else
    fprintf('*** EYELINK DISABLED (isEyelink = 0) - No eye tracking ***\n');
end

if isEyelink
    Eyelink('Command', 'set_idle_mode');
    Eyelink('Command', 'clear_screen 0');
    Eyelink('StartRecording');
    eyeUsed = Eyelink('EyeAvailable');
    if eyeUsed == 2
        eyeUsed = 1;
    end
    Eyelink('message', 'SYNCTIME');
end

% Define confirmQuit as a nested function handle
confirmQuit = @() confirmQuitDialog(window, white, grey, black);

%----------------------------------------------------------------------
%%                   INITIALIZE DATA STORAGE
%----------------------------------------------------------------------
csv_data = [];
csv_trial_counter = 0;  % Counter for VALID trials only

% Create CSV filename now for incremental saving (crash-safe)
time_start = clock;
csv_filename = sprintf('%s_FLE_E2_%04d_%02d_%02d_%02d_%02d.csv', ...
    sbjname, time_start(1), time_start(2), time_start(3), time_start(4), time_start(5));
csv_filepath = fullfile(data_folder, csv_filename);
csv_header = {'version', 'block', 'trial', 'condition', 'valid', 'motion_direction', ...
    'quadrant', 'eccentricity_dva', 'flash_relative_to_trajectory', ...
    'jitter_dva', 'flash_onset_frame', 'flash_onset_ms', ...
    'flash_frames', 'target_dva', 'target_x_dva', 'target_y_dva', ...
    'probe_initial', 'probe_dva', 'probe_x_dva', 'probe_y_dva', ...
    'foveal_offset', 'x_offset', 'y_offset'};

%======================================================================
%%                        MAIN EXPERIMENT LOOP
%======================================================================

for blockIdx = 1:numBlocks
    
    currentCondition = blockOrder(blockIdx);
    currentConditionName = conditionNames{currentCondition};
    trials = all_trials{currentCondition};
    numTrials = size(trials, 1);
    
    %------------------------------------------------------------------
    %                    BLOCK INSTRUCTION SCREEN
    %------------------------------------------------------------------
    Screen('FillRect', window, black);
    Screen('TextSize', window, 20);
    Screen('TextFont', window, 'Futura');
    
    % Show block progress
    progressText = sprintf('Block %d of %d\n\n', blockIdx, numBlocks);
    instructionText = [progressText, conditionInstructions{currentCondition}, ...
        '\n\n\nPress any key to begin.'];
    
    DrawFormattedText(window, instructionText, 'center', 'center', white);
    Screen('Flip', window);
    
    % Wait for any key press (ESC to quit)
    KbReleaseWait();
    waiting = true;
    while waiting
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown
            if keyCode(KbName('ESCAPE'))
                if confirmQuit()
                    % Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS
                    ListenChar(0);
                    ShowCursor;
                    sca;
                    return;
                end
                % Redraw instruction screen after cancel
                DrawFormattedText(window, instructionText, 'center', 'center', white);
                Screen('Flip', window);
                KbReleaseWait();
            else
                waiting = false;
            end
        end
    end
    KbReleaseWait();
    
    if isEyelink
        Eyelink('Message', 'BLOCK %d CONDITION %s', blockIdx, currentConditionName);
    end
    
    % Brief pause before first trial (no user input needed)
    Screen('FillRect', window, black);
    Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
    Screen('Flip', window);
    WaitSecs(0.5);
    
    %------------------------------------------------------------------
    %   INITIALIZE PER-BLOCK INVALID TRIAL QUEUE
    %------------------------------------------------------------------
    invalidTrialsQueue = [];  % Will store structs of trials to repeat
    maxRepeatAttempts = 3;    % Safety to avoid infinite looping if fixation impossible
    numTrialsThisBlock = numTrials;  % Will increase as invalid trials are queued
    trialAttemptCount = ones(1, numTrials);  % Track attempt count for each trial (starts at 1)
    
    %------------------------------------------------------------------
    %                    TRIAL LOOP (while loop for repeat support)
    %------------------------------------------------------------------
    
    trial = 1;
    while trial <= numTrialsThisBlock
        
        %--------------------------------------------------------------
        %                FIXATE + 3-2-1 COUNTDOWN TO BEGIN TRIAL
        %--------------------------------------------------------------
        % Counterbalance probe start position (50% fixation, 50% peripheral)
        probeStartsAtFixation = mod(trial, 2) == 1;  % Odd trials = fixation, even = peripheral
        
        KbReleaseWait();
        
        % 3-2-1 countdown with gaze checking
        countdownNumbers = {'3', '2', '1'};
        countdownDuration = 0.5;  % seconds per number
        
        countIdx = 1;
        while countIdx <= 3
            countdownStartTime = GetSecs();
            countdownViolated = false;
            
            while (GetSecs() - countdownStartTime) < countdownDuration
                % Check gaze if eye tracking is enabled
                gazeOK = true;  % Default OK if no eye tracking
                if isEyelink
                    evt = Eyelink('NewestFloatSample');
                    if isstruct(evt) && eyeUsed ~= -1 && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                        eyeX = evt.gx(eyeUsed + 1);
                        eyeY = evt.gy(eyeUsed + 1);
                        if eyeX ~= MISSING_DATA && eyeY ~= MISSING_DATA && ~isnan(eyeX) && ~isnan(eyeY)
                            gazeDistFromFix = hypot(eyeX - xCenter, eyeY - yCenter);
                            gazeOK = gazeDistFromFix < gazeThresholdPix;
                        else
                            % Missing eye data = treat as violation (eyes removed from tracker)
                            gazeOK = false;
                        end
                    else
                        % No valid sample structure = treat as violation
                        gazeOK = false;
                    end
                end
                
                % Draw fixation cross with countdown number behind it
                Screen('FillRect', window, black);
                Screen('TextSize', window, 72);
                
                % Show countdown or gaze warning
                if gazeOK
                    % Calculate fade: starts bright, fades to darker during each number
                    elapsedRatio = (GetSecs() - countdownStartTime) / countdownDuration;
                    elapsedRatio = min(1, max(0, elapsedRatio));  % Clamp 0-1
                    fadeBrightness = grey * (1.0 - 0.6 * elapsedRatio);  % Fade from grey to ~40% grey
                    
                    % Draw large countdown number with fading brightness
                    DrawFormattedText(window, countdownNumbers{countIdx}, 'center', 'center', fadeBrightness);
                else
                    % Gaze violation - will reset countdown to 3
                    Screen('TextSize', window, 24);
                    DrawFormattedText(window, 'Hold fixation to continue', 'center', yCenter - 60, softRed);
                    countdownViolated = true;
                end
                
                % Always draw fixation cross on top
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                Screen('Flip', window);
                
                % Check for escape
                [keyIsDown, ~, keyCode] = KbCheck();
                if keyIsDown
                    if keyCode(KbName('ESCAPE'))
                        if confirmQuit()
                            % Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS
                            ListenChar(0);
                            ShowCursor;
                            sca;
                            return;
                        end
                        KbReleaseWait();
                    end
                end
                
                % Flush any mouse clicks during this phase
                [~, ~, buttons] = GetMouse(window);
            end
            
            % After this countdown step: reset to 3 if violated, else advance
            if countdownViolated
                countIdx = 1;  % Reset to '3'
            else
                countIdx = countIdx + 1;  % Advance to next number
            end
        end
        
        % Reset background color and gaze tracking
        backgroundColor = black;
        gazeViolationDuringMotion = false;
        fixationOutside2DVA_prev = false;  % Track previous state for sound edge detection
        
        % Get trial parameters
        quad = trials(trial, 1);
        motionDir = trials(trial, 2);      % -1=petal, 0=none, 1=fugal
        eccDva = trials(trial, 3);         % Base eccentricity in DVA
        flashSide = trials(trial, 4);      % -1=left, 1=right (perpendicular)
        jitterDva = trials(trial, 5);      % Jitter in DVA
        
        % Get indices for pre-computed pixel arrays
        eccIdx = find(flash.EccentricityDva == eccDva);
        jitterIdx = find(flash.JitterDva == jitterDva);
        
        % Get flash eccentricity in pixels (pre-computed)
        flashEccDva = eccDva + jitterDva;  % For logging only
        flashEccPix = flash.EccentricityPix(eccIdx) + flash.JitterPix(jitterIdx);
        
        % timingMode only used for flashbaseline condition (stores timing pattern)
        timingMode = NaN;
        if currentCondition == 1
            timingMode = motionDir;  % Save for CSV output
        end
        
        %--------------------------------------------------------------
        %                QUADRANT-SPECIFIC SETUP
        %--------------------------------------------------------------
        if quad == 45        % Upper-right
            phaseshiftFactorX = 1;
            phaseshiftFactorY = -1;
            barAngle = 135;
        elseif quad == 135   % Upper-left
            phaseshiftFactorX = -1;
            phaseshiftFactorY = -1;
            barAngle = 45;
        elseif quad == 225   % Lower-left
            phaseshiftFactorX = -1;
            phaseshiftFactorY = 1;
            barAngle = 135;
        elseif quad == 315   % Lower-right
            phaseshiftFactorX = 1;
            phaseshiftFactorY = 1;
            barAngle = 45;
        end
        
        %--------------------------------------------------------------
        %                SHOW FIXATION
        %--------------------------------------------------------------
        fixationViolatedDuringFix = false;
        
        % Ensure cursor stays hidden during trial
        HideCursor(screenNumber);
        
        Screen('FillRect', window, black);
        Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
        fixationStartTime = Screen('Flip', window);
        
        while GetSecs() - fixationStartTime < fixDuration
            % Check for ESC key to quit
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown && keyCode(KbName('ESCAPE'))
                if confirmQuit()
                    % Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS
                    ListenChar(0);
                    ShowCursor;
                    sca;
                    return;
                end
                % Reset fixation timing after confirmation cancelled
                fixationStartTime = GetSecs();
            end
            
            % Gaze monitoring during fixation - always try to get newest sample (more reliable)
            if isEyelink
                evt = Eyelink('NewestFloatSample');
                if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                    gx = evt.gx(eyeUsed+1); 
                    gy = evt.gy(eyeUsed+1);
                    if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                        gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                        if gazeDistPix > gazeThresholdPix
                            fixationViolatedDuringFix = true;
                            gazeViolationDuringMotion = true;  % Invalidate trial for fixation violations
                        end
                    else
                        % Missing eye data = treat as violation (eyes removed from tracker)
                        fixationViolatedDuringFix = true;
                        gazeViolationDuringMotion = true;
                    end
                else
                    % No valid sample structure = treat as violation
                    fixationViolatedDuringFix = true;
                    gazeViolationDuringMotion = true;
                end
            end
            Screen('FillRect', window, black);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            Screen('Flip', window);
        end
        
        if isEyelink
            Eyelink('Message', 'TRIALID %d', trial);
        end
        
        %--------------------------------------------------------------
        %                STIMULUS PRESENTATION
        %--------------------------------------------------------------
        
        % Initialize variables
        flashFrameCounter = 0;
        barLocWhenFlashX = NaN;
        barLocWhenFlashY = NaN;
        barDistWhenFlashDva = NaN;  % Theoretical DVA value
        flashLocX = NaN;
        flashLocY = NaN;
        
        %------------------------------------------------------------------
        % FLASH ONSET FRAME COMPUTATION
        %------------------------------------------------------------------
        flashDurationFrames = flash.presentFrame;
        flashLeadFrames = 2;  % Trigger this many frames before bar reaches target
        
        if currentCondition == 1  % Flash baseline: no motion, use timing based on timingMode
            if timingMode == 1  % Fugal timing
                distanceToTrigger = flashEccPix - bar.startDistPix;
            else  % Petal timing
                distanceToTrigger = bar.endDistPix - flashEccPix;
            end
            flashOnsetFrame = max(1, round(distanceToTrigger / bar.speedPixPerFrame) + 1 - flashLeadFrames);
        elseif motionDir == 1  % Fugal
            distanceToTrigger = flashEccPix - bar.startDistPix;
            flashOnsetFrame = max(1, round(distanceToTrigger / bar.speedPixPerFrame) + 1 - flashLeadFrames);
        else  % Petal
            distanceToTrigger = bar.endDistPix - flashEccPix;
            flashOnsetFrame = max(1, round(distanceToTrigger / bar.speedPixPerFrame) + 1 - flashLeadFrames);
        end
        
        %------------------------------------------------------------------
        % TARGET DVA FOR MEASUREMENTS
        %------------------------------------------------------------------
        if motionDir == 0  % No motion (flash baseline)
            barCenterAtFlashEndDva = NaN;
        else
            barCenterAtFlashEndDva = flashEccDva;  % Target is always flash eccentricity
        end
        
        % Animation loop
        if currentCondition == 1  % flashbaseline - flash alone
            %----------------------------------------------------------
            % FLASH BASELINE: Flash only, no visible bar
            % Uses same timing as motion conditions (flashOnsetFrame)
            %----------------------------------------------------------
            totalFrames = refreshRate * 1;  % 1 second total
            
            % Pre-compute flash position
            flashBaseX = xCenter + phaseshiftFactorX * flashEccPix * sin45;
            flashBaseY = yCenter + phaseshiftFactorY * flashEccPix * cos45;
            
            if quad == 45 || quad == 225
                perpX = flashSide * flash.TotalOffsetPix * cos45;
                perpY = flashSide * flash.TotalOffsetPix * sin45;
            else
                perpX = -flashSide * flash.TotalOffsetPix * cos45;
                perpY = flashSide * flash.TotalOffsetPix * sin45;
            end
            
            flashLocX = flashBaseX + perpX;
            flashLocY = flashBaseY + perpY;
            flashRect = CenterRectOnPoint(flash.Rect, flashLocX, flashLocY);
            
            % Calculate actual flash center DVA (Euclidean distance from fixation)
            flashCenterDistPix = sqrt((flashLocX - xCenter)^2 + (flashLocY - yCenter)^2);
            flashCenterDva = pix2dva(flashCenterDistPix, eyeScreenDistance, windowRect, screenHeight);
            
            % Initialize VBL for scheduled flips (draw fixation to prevent blank frame)
            Screen('FillRect', window, backgroundColor);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            vbl = Screen('Flip', window);
            
            for frame = 1:totalFrames
                Screen('FillRect', window, backgroundColor);
                
                % Flash ON from flashOnsetFrame for exactly flashDurationFrames (4 frames)
                isFlashWindow = (frame >= flashOnsetFrame) && (frame < flashOnsetFrame + flashDurationFrames);
                
                if isFlashWindow
                    Screen('DrawTexture', window, flash.Texture, [], flashRect, barAngle);
                    flashFrameCounter = flashFrameCounter + 1;
                    
                    if isEyelink && flashFrameCounter == 1
                        Eyelink('Message', 'FLASH');
                    end
                end
                
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                Screen('DrawingFinished', window);
                vbl = Screen('Flip', window, vbl + 0.5*ifi);  % Schedule half-frame ahead
                
                % Gaze monitoring - always try to get newest sample (more reliable)
                if isEyelink
                    evt = Eyelink('NewestFloatSample');
                    eyeDataMissing = true;  % Assume missing until proven otherwise
                    if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                        gx = evt.gx(eyeUsed+1); 
                        gy = evt.gy(eyeUsed+1);
                        if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                            eyeDataMissing = false;
                            gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                            outside2 = gazeDistPix > gazeThresholdPix;
                            
                            if outside2
                                gazeViolationDuringMotion = true;
                            end
                            
                            if outside2 && ~fixationOutside2DVA_prev
                                % Play warning sound
                                try PsychPortAudio('Stop', pahandle_warning, 1); PsychPortAudio('Start', pahandle_warning, 1, 0, 0); catch, end
                                break;  % Exit the animation loop
                            end
                            
                            fixationOutside2DVA_prev = outside2;
                        end
                    end
                    % Missing eye data = treat as violation (eyes removed from tracker)
                    if eyeDataMissing
                        gazeViolationDuringMotion = true;
                        try PsychPortAudio('Stop', pahandle_warning, 1); PsychPortAudio('Start', pahandle_warning, 1, 0, 0); catch, end
                        fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\n');
                        break;
                    end
                end
            end
            
        else  % Motion conditions (2, 3, 4)
            %----------------------------------------------------------
            % MOTION CONDITIONS: Moving bar with flash or fixation cue
            % Flash stays STATIONARY - bar moves past it (like flash_lag)
            % Uses POSITION-BASED flash triggering (not frame-based)
            %----------------------------------------------------------
            % MOTION CONDITIONS (2, 3, 4): Bar moves, flash/cue at pre-computed frame
            %----------------------------------------------------------
            
            % Set initial bar position based on motion direction
            if motionDir == 1  % Fugal (outward)
                barDist = bar.startDistPix;
            else  % Petal (inward)
                barDist = bar.endDistPix;
            end
            
            totalFrames = round(bar.movDistPix / bar.speedPixPerFrame);
            
            % Pre-calculate flash position (offset perpendicular to trajectory)
            if quad == 45 || quad == 225
                perpX = flashSide * flash.TotalOffsetPix * cos45;
                perpY = flashSide * flash.TotalOffsetPix * sin45;
            else
                perpX = -flashSide * flash.TotalOffsetPix * cos45;
                perpY = flashSide * flash.TotalOffsetPix * sin45;
            end
            
            flashBaseX = xCenter + phaseshiftFactorX * flashEccPix * sin45;
            flashBaseY = yCenter + phaseshiftFactorY * flashEccPix * cos45;
            flashLocX = flashBaseX + perpX;
            flashLocY = flashBaseY + perpY;
            flashRect = CenterRectOnPoint(flash.Rect, flashLocX, flashLocY);
            
            % Calculate actual flash center DVA (Euclidean distance from fixation)
            flashCenterDistPix = sqrt((flashLocX - xCenter)^2 + (flashLocY - yCenter)^2);
            flashCenterDva = pix2dva(flashCenterDistPix, eyeScreenDistance, windowRect, screenHeight);
            
            % Pre-compute trajectory multipliers
            trajMultX = phaseshiftFactorX * sin45;
            trajMultY = phaseshiftFactorY * cos45;
            
            % Initialize VBL for scheduled flips (draw fixation to prevent blank frame)
            Screen('FillRect', window, backgroundColor);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            vbl = Screen('Flip', window);
            
            for frame = 1:totalFrames
                Screen('FillRect', window, backgroundColor);
                
                % Calculate bar center position for this frame
                % (position updated at end of loop to ensure first frame shows initial position)
                barCenterX = xCenter + trajMultX * barDist;
                barCenterY = yCenter + trajMultY * barDist;
                
                barRect = [barCenterX - bar.HalfWidth, barCenterY - bar.HalfLength, ...
                           barCenterX + bar.HalfWidth, barCenterY + bar.HalfLength];
                
                % Draw moving bar
                Screen('DrawTexture', window, bar.Texture, [], barRect, barAngle);
                
                % Flash/cue ON from flashOnsetFrame for flashDurationFrames
                isFlashWindow = (frame >= flashOnsetFrame) && (frame < flashOnsetFrame + flashDurationFrames);
                lastFlashFrame = flashOnsetFrame + flashDurationFrames - 1;
                
                % Send EyeLink message on first flash frame
                if frame == flashOnsetFrame
                    if isEyelink
                        if currentCondition == 2
                            Eyelink('Message', 'FIXCUE');
                        else
                            Eyelink('Message', 'FLASH');
                        end
                    end
                end
                
                % Store bar position on LAST flash frame (final position while flash visible)
                if frame == lastFlashFrame
                    barLocWhenFlashX = barCenterX;
                    barLocWhenFlashY = barCenterY;
                    barDistWhenFlashDva = barCenterAtFlashEndDva;  % Theoretical DVA value
                end
                
                % Draw flash or cue based on condition
                if isFlashWindow
                    if currentCondition == 2  % centralcue - cue at fixation
                        flashFrameCounter = flashFrameCounter + 1;  % Track for CSV
                    else  % flash_motion (3) or motion_flash (4) - flash at target
                        Screen('DrawTexture', window, flash.Texture, [], flashRect, barAngle);
                        flashFrameCounter = flashFrameCounter + 1;
                    end
                end
                
                % Draw fixation (cue or cross)
                if currentCondition == 2 && isFlashWindow
                    if centralCueType == 1
                        Screen('DrawLines', window, fixCoords, fixLineWidth, red, [xCenter, yCenter]);
                    else
                        Screen('DrawTexture', window, centralCueTexture, [], centralCueDestRect, barAngle);
                    end
                else
                    Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                end
                
                Screen('DrawingFinished', window);
                vbl = Screen('Flip', window, vbl + 0.5*ifi);  % Schedule half-frame ahead
                
                % Gaze monitoring - always try to get newest sample (more reliable)
                if isEyelink
                    evt = Eyelink('NewestFloatSample');
                    eyeDataMissing = true;  % Assume missing until proven otherwise
                    if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                        gx = evt.gx(eyeUsed+1); 
                        gy = evt.gy(eyeUsed+1);
                        if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                            eyeDataMissing = false;
                            gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                            outside2 = gazeDistPix > gazeThresholdPix;
                            
                            if outside2
                                gazeViolationDuringMotion = true;
                            end
                            
                            if outside2 && ~fixationOutside2DVA_prev
                                % Play warning sound
                                try PsychPortAudio('Stop', pahandle_warning, 1); PsychPortAudio('Start', pahandle_warning, 1, 0, 0); catch, end
                                fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\n');
                                break;  % Exit the animation loop
                            end
                            
                            fixationOutside2DVA_prev = outside2;
                        end
                    end
                    % Missing eye data = treat as violation (eyes removed from tracker)
                    if eyeDataMissing
                        gazeViolationDuringMotion = true;
                        try PsychPortAudio('Stop', pahandle_warning, 1); PsychPortAudio('Start', pahandle_warning, 1, 0, 0); catch, end
                        fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\n');
                        break;
                    end
                end
                
                % Update bar position for next frame (after drawing current frame)
                barDist = barDist + motionDir * bar.speedPixPerFrame;
            end
        end
        
        % Check for NaN target locations (stimulus loop exited abnormally)
        if currentCondition == 1 || currentCondition == 3
            if isnan(flashLocX) || isnan(flashLocY)
                gazeViolationDuringMotion = true;
            end
        elseif currentCondition == 2 || currentCondition == 4
            if isnan(barLocWhenFlashX) || isnan(barLocWhenFlashY)
                gazeViolationDuringMotion = true;
            end
        end
        
        %--------------------------------------------------------------
        %      HANDLE GAZE VIOLATION: Silent invalidation, continue to next trial
        %--------------------------------------------------------------
        if gazeViolationDuringMotion
            % Brief pause before next trial
            WaitSecs(0.1);
            
            % Set response values to NaN for invalid trial
            probeDisplayDva = NaN;
            totalOffsetDva = NaN;
            reportedOffsetDva = NaN;
            probeInitialText = NaN;  % For CSV
            wrongQuadrant = false;  % Not applicable - gaze violation occurred before response
            
            % Target DVA is flashEccDva for all conditions
            targetDva = flashEccDva;
            
            % Build trial info string for invalid trial (same format as valid)
            flashEccDva_log = flashEccDva;  % Use theoretical value directly
            flashOnsetTime_ms = (flashOnsetFrame / refreshRate) * 1000;
            
            switch quad
                case 45
                    quadName = 'UPPER RIGHT';
                case 135
                    quadName = 'UPPER LEFT';
                case 225
                    quadName = 'LOWER LEFT';
                case 315
                    quadName = 'LOWER RIGHT';
            end
            
            if motionDir == 1
                motionText_display = 'FUGAL';
            elseif motionDir == -1
                motionText_display = 'PETAL';
            else
                motionText_display = '';
            end
            
            switch currentCondition
                case 1
                    condDisplay = 'FLASH BL';
                case 2
                    condDisplay = 'CENTRAL CUE';
                case 3
                    condDisplay = 'FLASH+MOTION';
                case 4
                    condDisplay = 'MOTION+FLASH';
            end
            
            % Queue trial for repetition at end of block (with attempt tracking)
            currentAttempt = trialAttemptCount(trial);
            
            if currentAttempt < maxRepeatAttempts
                queuedTrial.quad = quad;
                queuedTrial.motionDir = motionDir;
                queuedTrial.eccDva = eccDva;
                queuedTrial.flashSide = flashSide;
                queuedTrial.jitterDva = jitterDva;
                queuedTrial.attemptCount = currentAttempt + 1;  % Next attempt number
                invalidTrialsQueue = [invalidTrialsQueue, queuedTrial];
                trialAttemptCount(trial) = trialAttemptCount(trial) + 1;  % Mark this trial as attempted
                
                % Print in same format as valid trials, with INVALID at end
                if currentCondition == 2
                    fprintf('B%d T--: %s | %s | %s | CUE @ %.0fdva (%.0f %+.0f) | ONSET @ %.0fms | INVALID (attempt %d/%d)\n', ...
                        blockIdx, condDisplay, motionText_display, quadName, ...
                        flashEccDva_log, eccDva, jitterDva, flashOnsetTime_ms, currentAttempt, maxRepeatAttempts);
                elseif currentCondition == 1
                    if quad == 45 || quad == 135
                        if flashSide == 1
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        else
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        end
                    else
                        if flashSide == 1
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        else
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        end
                    end
                    fprintf('B%d T--: %s | %s | FLASH @ %.0fdva (%.0f %+.0f) | %s | ONSET @ %.0fms | INVALID (attempt %d/%d)\n', ...
                        blockIdx, condDisplay, quadName, ...
                        flashEccDva_log, eccDva, jitterDva, flashRelDisplay, flashOnsetTime_ms, currentAttempt, maxRepeatAttempts);
                else
                    if quad == 45 || quad == 135
                        if flashSide == 1
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        else
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        end
                    else
                        if flashSide == 1
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        else
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        end
                    end
                    fprintf('B%d T--: %s | %s | %s | FLASH @ %.0fdva (%.0f %+.0f) | %s | ONSET @ %.0fms | INVALID (attempt %d/%d)\n', ...
                        blockIdx, condDisplay, motionText_display, quadName, ...
                        flashEccDva_log, eccDva, jitterDva, flashRelDisplay, flashOnsetTime_ms, currentAttempt, maxRepeatAttempts);
                end
            else
                % Max attempts reached - print with FAILED
                if currentCondition == 2
                    fprintf('B%d T%d: %s | %s | %s | CUE @ %.0fdva (%.0f %+.0f) | ONSET @ %.0fms | FAILED (max attempts)\n', ...
                        blockIdx, trial, condDisplay, motionText_display, quadName, ...
                        flashEccDva_log, eccDva, jitterDva, flashOnsetTime_ms);
                elseif currentCondition == 1
                    if quad == 45 || quad == 135
                        if flashSide == 1
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        else
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        end
                    else
                        if flashSide == 1
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        else
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        end
                    end
                    fprintf('B%d T%d: %s | %s | FLASH @ %.0fdva (%.0f %+.0f) | %s | ONSET @ %.0fms | FAILED (max attempts)\n', ...
                        blockIdx, trial, condDisplay, quadName, ...
                        flashEccDva_log, eccDva, jitterDva, flashRelDisplay, flashOnsetTime_ms);
                else
                    if quad == 45 || quad == 135
                        if flashSide == 1
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        else
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        end
                    else
                        if flashSide == 1
                            flashRelDisplay = 'BELOW TRAJECTORY';
                        else
                            flashRelDisplay = 'ABOVE TRAJECTORY';
                        end
                    end
                    fprintf('B%d T%d: %s | %s | %s | FLASH @ %.0fdva (%.0f %+.0f) | %s | ONSET @ %.0fms | FAILED (max attempts)\n', ...
                        blockIdx, trial, condDisplay, motionText_display, quadName, ...
                        flashEccDva_log, eccDva, jitterDva, flashRelDisplay, flashOnsetTime_ms);
                end
            end
        else
            %--------------------------------------------------------------
            %                RESPONSE COLLECTION (Method of Adjustment)
            %--------------------------------------------------------------
            
            % Print trial info BEFORE response
            flashEccDva_log = pix2dva(flashEccPix, eyeScreenDistance, windowRect, screenHeight);
            flashOnsetTime_ms = (flashOnsetFrame / refreshRate) * 1000;
            
            % Format quadrant as position name
            switch quad
                case 45
                    quadName = 'UPPER RIGHT';
                case 135
                    quadName = 'UPPER LEFT';
                case 225
                    quadName = 'LOWER LEFT';
                case 315
                    quadName = 'LOWER RIGHT';
            end
            
            % Format condition name for display
            switch currentCondition
                case 1
                    condDisplay = 'FLASH BL';
                case 2
                    condDisplay = 'CENTRAL CUE';
                case 3
                    condDisplay = 'FLASH+MOTION';
                case 4
                    condDisplay = 'MOTION+FLASH';
            end
            
            % Build output based on condition (print before response, add PROBE after)
            if currentCondition == 2
                if motionDir == 1
                    motionText = 'FUGAL';
                else
                    motionText = 'PETAL';
                end
                trialInfoStr = sprintf('B%d T%d: %s | %s | %s | CUE @ %.0fdva (%.0f %+.0f) | ONSET @ %.0fms', ...
                    blockIdx, trial, condDisplay, motionText, quadName, ...
                    flashEccDva_log, eccDva, jitterDva, flashOnsetTime_ms);
            elseif currentCondition == 1
                % Flash Baseline: compute flash relative position
                if quad == 45 || quad == 135
                    if flashSide == 1
                        flashRelDisplay = 'ABOVE TRAJECTORY';
                    else
                        flashRelDisplay = 'BELOW TRAJECTORY';
                    end
                else
                    if flashSide == 1
                        flashRelDisplay = 'BELOW TRAJECTORY';
                    else
                        flashRelDisplay = 'ABOVE TRAJECTORY';
                    end
                end
                trialInfoStr = sprintf('B%d T%d: %s | %s | FLASH @ %.0fdva (%.0f %+.0f) | %s | ONSET @ %.0fms', ...
                    blockIdx, trial, condDisplay, quadName, ...
                    flashEccDva_log, eccDva, jitterDva, flashRelDisplay, flashOnsetTime_ms);
            else
                % Flash+Motion or Motion+Flash
                if motionDir == 1
                    motionText = 'FUGAL';
                else
                    motionText = 'PETAL';
                end
                if quad == 45 || quad == 135
                    if flashSide == 1
                        flashRelDisplay = 'ABOVE TRAJECTORY';
                    else
                        flashRelDisplay = 'BELOW TRAJECTORY';
                    end
                else
                    if flashSide == 1
                        flashRelDisplay = 'BELOW TRAJECTORY';
                    else
                        flashRelDisplay = 'ABOVE TRAJECTORY';
                    end
                end
                trialInfoStr = sprintf('B%d T%d: %s | %s | %s | FLASH @ %.0fdva (%.0f %+.0f) | %s | ONSET @ %.0fms', ...
                    blockIdx, trial, condDisplay, motionText, quadName, ...
                    flashEccDva_log, eccDva, jitterDva, flashRelDisplay, flashOnsetTime_ms);
            end
            
            % Brief pause before probe (frame-based)
            for intervalFrame = 1:probe.intervalFrames
                Screen('FillRect', window, black);
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                Screen('Flip', window);
            end
            
            % Target location for probe placement depends on what's being localized
            if currentCondition == 1 || currentCondition == 3
                % Localizing FLASH - use flash center position
                targetLocX = flashLocX;
                targetLocY = flashLocY;
            else
                % Localizing MOVING BAR - use bar position on trajectory
                targetLocX = barLocWhenFlashX;
                targetLocY = barLocWhenFlashY;
            end
            
            % Target DVA is ALWAYS flashEccDva - the base eccentricity (6, 7, 8 DVA etc.)
            targetDva = flashEccDva;
            
            % Probe start position - counterbalanced (set at trial start)
            if probeStartsAtFixation
                probeStartX = xCenter;
                probeStartY = yCenter;
                probeInitialText = 'centre';
            else
                % Start at peripheral position along a random diagonal
                randomQuadrantIdx = randi(4);
                peripheralQuadrant = quadrants(randomQuadrantIdx);
                
                % Use precomputed peripheral distance
                probeStartX = xCenter + probe.PeripheralStartPix * sind(peripheralQuadrant);
                probeStartY = yCenter - probe.PeripheralStartPix * cosd(peripheralQuadrant);
                
                % Set text label based on quadrant
                switch peripheralQuadrant
                    case 45
                        probeInitialText = 'upper_right';
                    case 135
                        probeInitialText = 'upper_left';
                    case 225
                        probeInitialText = 'lower_left';
                    case 315
                        probeInitialText = 'lower_right';
                end
            end
            
            % Setup response phase
            HideCursor(screenNumber);
            % Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS
            
            % Initialize mouse at probe start position - use screenNumber for macOS
            SetMouse(round(probeStartX), round(probeStartY), screenNumber);
            probeX = probeStartX;
            probeY = probeStartY;
            
            % Flush keyboard state before entering response loop
            KbReleaseWait();
            
            % Response loop - absolute mouse position
            respToBeMade = true;
            repeatTrialRequested = false;
            
            % Track mouse stillness for dynamic text color
            lastMouseX = probeStartX;
            lastMouseY = probeStartY;
            mouseStillSince = GetSecs();
            mouseStillThreshold = 0.3;  % 300ms to turn white
            hasMovedProbe = false;  % Must move probe before it can turn white
            
            while respToBeMade
                % Enforce cursor hidden every frame (macOS requirement)
                HideCursor(screenNumber);
                
                % Absolute mouse position - no delta integration
                [probeX, probeY, ~] = GetMouse(window);
                
                % Clamp to screen bounds and WARP mouse back if outside
                % (ConstrainCursor unreliable on macOS multi-monitor setups)
                clampedX = max(10, min(windowRect(3) - 10, probeX));
                clampedY = max(10, min(windowRect(4) - 10, probeY));
                if probeX ~= clampedX || probeY ~= clampedY
                    SetMouse(round(clampedX), round(clampedY), screenNumber);
                end
                probeX = clampedX;
                probeY = clampedY;
                
                % Check if mouse has moved - update stillness timer
                if abs(probeX - lastMouseX) > 1 || abs(probeY - lastMouseY) > 1
                    mouseStillSince = GetSecs();
                    lastMouseX = probeX;
                    lastMouseY = probeY;
                    hasMovedProbe = true;  % Mark that probe has been moved
                end
                
                % Determine text and probe color based on stillness (only after movement)
                if hasMovedProbe && (GetSecs() - mouseStillSince) >= mouseStillThreshold
                    confirmTextColor = white;  % Mouse still for 300ms+
                    probeColorMod = [255 255 255];  % Bright white probe
                else
                    confirmTextColor = grey;   % Mouse moving or hasn't moved yet
                    probeColorMod = [grey grey grey];  % Grey probe
                end
                
                % Draw
                Screen('FillRect', window, black);
                Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                if currentCondition == 2 || currentCondition == 4
                    probeDestRect = CenterRectOnPoint(probe.BarRect, probeX, probeY);
                    Screen('DrawTexture', window, probe.BarTexture, [], probeDestRect, barAngle, [], [], probeColorMod);
                else
                    probeDestRect = CenterRectOnPoint(probe.Rect, probeX, probeY);
                    Screen('DrawTexture', window, probe.Texture, [], probeDestRect, barAngle, [], [], probeColorMod);
                end
                
                % Task reminder while moving, confirmation when still
                Screen('TextSize', window, 16);
                if hasMovedProbe && (GetSecs() - mouseStillSince) >= mouseStillThreshold
                    % Mouse still - show confirmation prompt
                    bottomText = 'Click to confirm';
                else
                    % Mouse moving - show task reminder
                    if currentCondition == 2 || currentCondition == 4
                        bottomText = 'Where was the moving bar at the time of the flash?';
                    else
                        bottomText = 'Where was the flash?';
                    end
                end
                DrawFormattedText(window, bottomText, 'center', windowRect(4) - 40, confirmTextColor);
                Screen('Flip', window);
                
                % Check for mouse click to confirm
                [~, ~, buttons] = GetMouse(window);
                if any(buttons)
                    % Play subtle tick sound for confirmation
                    try
                        PsychPortAudio('Stop', pahandle_tick);
                        PsychPortAudio('Start', pahandle_tick, 1, 0, 0);
                    catch
                    end
                    respToBeMade = false;
                end
                
                % Check keys (R to repeat trial)
                [~, ~, keyCode] = KbCheck();
                if keyCode(KbName('r'))
                    repeatTrialRequested = true;
                    respToBeMade = false;
                end
            end
            
            % Wait for mouse button release before continuing
            while any(buttons)
                [~, ~, buttons] = GetMouse(window);
            end
            
            % Release cursor constraint
            % Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS
            
            % Store final probe position
            finalProbeCenterX = probeX;
            finalProbeCenterY = probeY;
            
            % If repeat requested, skip data storage and re-run this trial immediately
            if repeatTrialRequested
                fprintf('Trial %d: INVALIDATED - Repeat requested by experimenter (R key)\n', trial);
                continue;  % Skip to next iteration - trial number stays same, same trial params used
            end
            
            % Check if probe is in wrong quadrant (invalidates trial)
            % Determine probe quadrant based on position relative to fixation
            probeRelX = finalProbeCenterX - xCenter;
            probeRelY = finalProbeCenterY - yCenter;
            if probeRelX >= 0 && probeRelY <= 0  % Upper right (screen Y inverted)
                probeQuadrant = 45;
            elseif probeRelX < 0 && probeRelY <= 0  % Upper left
                probeQuadrant = 135;
            elseif probeRelX < 0 && probeRelY > 0  % Lower left
                probeQuadrant = 225;
            else  % Lower right
                probeQuadrant = 315;
            end
            
            % Check if probe is in different quadrant than target
            wrongQuadrant = (probeQuadrant ~= quad);
            
            % Calculate final probe position as ACTUAL Euclidean distance from fixation
            % This is the true distance from screen center to probe center
            finalProbeDistPix = sqrt((finalProbeCenterX - xCenter)^2 + (finalProbeCenterY - yCenter)^2);
            
            % Convert final probe distance to DVA
            probeDisplayDva = pix2dva(finalProbeDistPix, eyeScreenDistance, windowRect, screenHeight);
            
            % Target DVA was already computed theoretically above (flashEccDva)
            % This is the radial distance from fixation to target center
            
            % OFFSET = final probe position - target position (probe minus target)
            totalOffsetDva = probeDisplayDva - targetDva;
            
            % Print complete trial info on single line (values match CSV columns)
            fprintf('%s | TARGET: %.2f | INIT: %s | PROBE: %.2f | OFFSET: %+.2f dva\n', ...
                trialInfoStr, targetDva, probeInitialText, probeDisplayDva, totalOffsetDva);
            
            % Store for CSV (reportedOffsetDva is the total offset from target)
            reportedOffsetDva = totalOffsetDva;
            
            % Check if probe was placed in wrong quadrant - queue for repeat
            if wrongQuadrant
                % Queue trial for repetition at end of block (with attempt tracking)
                currentAttempt = trialAttemptCount(trial);
                
                if currentAttempt < maxRepeatAttempts
                    queuedTrial.quad = quad;
                    queuedTrial.motionDir = motionDir;
                    queuedTrial.eccDva = eccDva;
                    queuedTrial.flashSide = flashSide;
                    queuedTrial.jitterDva = jitterDva;
                    queuedTrial.attemptCount = currentAttempt + 1;
                    invalidTrialsQueue = [invalidTrialsQueue, queuedTrial];
                    trialAttemptCount(trial) = trialAttemptCount(trial) + 1;
                    
                    fprintf('  *** WRONG QUADRANT - Probe in Q%d, target in Q%d (attempt %d/%d) ***\n', ...
                        probeQuadrant, quad, currentAttempt, maxRepeatAttempts);
                else
                    fprintf('  *** WRONG QUADRANT - Max attempts reached, not repeating ***\n');
                end
            end
        end
        
        %--------------------------------------------------------------
        %                STORE TRIAL DATA
        %--------------------------------------------------------------
        % Log ALL trials to CSV (valid and invalid)
        % Valid trials get sequential trial numbers, invalid get 'NA'
        
        % Determine if trial is valid (no gaze violation AND correct quadrant)
        trialIsValid = ~gazeViolationDuringMotion && ~wrongQuadrant;
        
        if trialIsValid
            % Valid trial - increment counter and use sequential number
            csv_trial_counter = csv_trial_counter + 1;
            trial_identifier = csv_trial_counter;
        else
            % Invalid trial - use 'NA' as trial identifier
            trial_identifier = 'NA';
        end
        
        % Convert values to text for CSV
        if motionDir == 1
            motionText = 'fugal';
        elseif motionDir == -1
            motionText = 'petal';
        else
            motionText = 'none';
        end
        
        if quad == 45
            quadText = 'upper_right';
        elseif quad == 135
            quadText = 'upper_left';
        elseif quad == 225
            quadText = 'lower_left';
        else
            quadText = 'lower_right';
        end
        
        if gazeViolationDuringMotion
            validText = 'invalid_fixation';
        elseif wrongQuadrant
            validText = 'invalid_quadrant';
        else
            validText = 'valid';
        end
        
        % Determine flash position relative to bar trajectory (for conditions 1, 3, 4)
        % flashSide = 1 means flash is on one side, -1 on the other
        % This depends on quadrant and flashSide
        if currentCondition ~= 2  % Not central cue
            % For upper quadrants (45, 135): flashSide=1 means flash is ABOVE trajectory
            % For lower quadrants (225, 315): flashSide=1 means flash is BELOW trajectory
            if quad == 45 || quad == 135  % Upper quadrants
                if flashSide == 1
                    flashRelativeText = 'above_trajectory';
                else
                    flashRelativeText = 'below_trajectory';
                end
            else  % Lower quadrants (225, 315)
                if flashSide == 1
                    flashRelativeText = 'below_trajectory';
                else
                    flashRelativeText = 'above_trajectory';
                end
            end
        else
            flashRelativeText = NaN;  % Central cue has no flash
        end
        
        % Calculate timing info
        flashOnsetTime_ms = (flashOnsetFrame / refreshRate) * 1000;
        
        if trialIsValid
            targetDva_csv = targetDva;  % Theoretical DVA (exact value)
            % Convert target position to DVA (signed: negative = left/up of center)
            targetX_csv = pix2dva(abs(targetLocX - xCenter), eyeScreenDistance, windowRect, screenHeight) * sign(targetLocX - xCenter);
            targetY_csv = -pix2dva(abs(targetLocY - yCenter), eyeScreenDistance, windowRect, screenHeight) * sign(targetLocY - yCenter);  % Flip: screen Y down = negative DVA
            probeInitial_csv = probeInitialText;  % 'fixation' or 'peripheral'
            probeDva_csv = probeDisplayDva;  % Final position (converted from pixels)
            % Convert probe position to DVA (signed: negative = left/up of center)
            probeX_csv = pix2dva(abs(finalProbeCenterX - xCenter), eyeScreenDistance, windowRect, screenHeight) * sign(finalProbeCenterX - xCenter);
            probeY_csv = -pix2dva(abs(finalProbeCenterY - yCenter), eyeScreenDistance, windowRect, screenHeight) * sign(finalProbeCenterY - yCenter);  % Flip: screen Y down = negative DVA
            fovealOffset_csv = totalOffsetDva;  % Probe distance from fixation - target distance from fixation
            % Calculate x and y offsets in DVA (probe center - target center)
            % Negative x = probe left of target, Negative y = probe below target
            xOffsetPix = finalProbeCenterX - targetLocX;
            yOffsetPix = finalProbeCenterY - targetLocY;
            xOffset_csv = pix2dva(abs(xOffsetPix), eyeScreenDistance, windowRect, screenHeight) * sign(xOffsetPix);
            yOffset_csv = -pix2dva(abs(yOffsetPix), eyeScreenDistance, windowRect, screenHeight) * sign(yOffsetPix);  % Flip sign: screen Y increases downward
        else
            % For invalid trials (gaze violation or wrong quadrant), set probe values to NaN
            targetDva_csv = targetDva;  % Keep target info for reference
            targetX_csv = NaN;
            targetY_csv = NaN;
            probeInitial_csv = NaN;
            probeDva_csv = NaN;
            probeX_csv = NaN;
            probeY_csv = NaN;
            fovealOffset_csv = NaN;
            xOffset_csv = NaN;
            yOffset_csv = NaN;
        end
        
        % [block, trial, condition, valid, motion_dir, quadrant, eccentricity,
        %  flash_relative, jitter, flash_onset_frame, flash_onset_ms,
        %  flash_frames, target_dva, target_x, target_y, probe_initial, probe_dva, probe_x, probe_y,
        %  foveal_offset, x_offset, y_offset]
        csv_data = [csv_data; {exp.version, blockIdx, trial_identifier, currentConditionName, validText, ...
            motionText, quadText, eccDva, flashRelativeText, jitterDva, ...
            flashOnsetFrame, flashOnsetTime_ms, flashFrameCounter, ...
            targetDva_csv, targetX_csv, targetY_csv, probeInitial_csv, probeDva_csv, probeX_csv, probeY_csv, ...
            fovealOffset_csv, xOffset_csv, yOffset_csv}];
        
        % INCREMENTAL SAVE: Write data after each trial (crash-safe)
        try
            csv_table = cell2table(csv_data, 'VariableNames', csv_header);
            writetable(csv_table, csv_filepath);
        catch
            warning('Failed to save incremental data - will retry next trial');
        end
        
        %==============================================================
        %   PROCESS INVALID TRIALS QUEUE - CHECK AFTER EACH TRIAL
        %==============================================================
        % Check if we've finished all scheduled trials and have queued repeats
        if trial >= numTrialsThisBlock && ~isempty(invalidTrialsQueue)
            fprintf('\n*** Processing %d queued repeat trials ***\n', length(invalidTrialsQueue));
            for q = 1:length(invalidTrialsQueue)
                qt = invalidTrialsQueue(q);
                if qt.attemptCount <= maxRepeatAttempts
                    % Add trial back to trials array
                    newRow = [qt.quad, qt.motionDir, qt.eccDva, qt.flashSide, qt.jitterDva];
                    trials = [trials; newRow];
                    % Track attempt count for this new trial index
                    trialAttemptCount = [trialAttemptCount, qt.attemptCount];
                end
            end
            % Update total trials for this block so while-loop continues with repeats
            numTrialsThisBlock = size(trials, 1);
            % Clear the queue since we've appended everything
            invalidTrialsQueue = [];
        end
        
        %--------------------------------------------------------------
        %                INTER-TRIAL INTERVAL (fixation maintained)
        %--------------------------------------------------------------
        % Brief pause between trials with fixation cross maintained (frame-based)
        itiFrames = round(0.2 * refreshRate);  % 200ms ITI
        for itiFrame = 1:itiFrames
            Screen('FillRect', window, black);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            Screen('Flip', window);
        end
        
        % Increment trial counter
        trial = trial + 1;
        
    end  % End trial while loop
    
    %------------------------------------------------------------------
    %                    REST SCREEN BETWEEN BLOCKS
    %------------------------------------------------------------------
    if blockIdx < numBlocks
        % Calculate progress
        progressPercent = round(100 * blockIdx / numBlocks);
        
        % 20-second mandatory rest with countdown
        restDuration = 20;  % seconds
        restStartTime = GetSecs();
        
        % Progress bar parameters
        barWidth = 300;
        barHeight = 8;
        barLeft = xCenter - barWidth/2;
        barTop = yCenter + 80;
        barRect = [barLeft, barTop, barLeft + barWidth, barTop + barHeight];
        
        KbReleaseWait();
        
        while true
            elapsedRest = GetSecs() - restStartTime;
            remainingTime = max(0, ceil(restDuration - elapsedRest));
            
            Screen('FillRect', window, black);
            Screen('TextSize', window, 28);
            
            if remainingTime > 0
                % Still in mandatory rest period
                restText = sprintf('Block %d of %d complete  (%d%% done)\n\nTake a short break...', ...
                    blockIdx, numBlocks, progressPercent);
                DrawFormattedText(window, restText, 'center', yCenter - 60, white);
                
                % Draw progress bar outline (dark grey)
                Screen('FrameRect', window, grey * 0.5, barRect, 1);
                
                % Draw progress bar fill (dim blue - relaxing color)
                fillWidth = barWidth * (blockIdx / numBlocks);
                fillRect = [barLeft, barTop, barLeft + fillWidth, barTop + barHeight];
                Screen('FillRect', window, [60 80 120], fillRect);
                
                % Draw countdown timer below progress bar
                Screen('TextSize', window, 24);
                countdownText = sprintf('Resuming in %d seconds...', remainingTime);
                DrawFormattedText(window, countdownText, 'center', barTop + 40, grey);
            else
                % Rest period complete - can now continue
                restText = sprintf('Block %d of %d complete  (%d%% done)\n\nPress any key to continue.', ...
                    blockIdx, numBlocks, progressPercent);
                DrawFormattedText(window, restText, 'center', yCenter - 60, white);
                
                % Draw filled progress bar
                Screen('FrameRect', window, grey * 0.5, barRect, 1);
                fillWidth = barWidth * (blockIdx / numBlocks);
                fillRect = [barLeft, barTop, barLeft + fillWidth, barTop + barHeight];
                Screen('FillRect', window, [60 80 120], fillRect);
            end
            
            Screen('Flip', window);
            
            % Check for input
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown
                if keyCode(KbName('ESCAPE'))
                    if confirmQuit()
                        ListenChar(0);
                        ShowCursor;
                        sca;
                        return;
                    end
                    KbReleaseWait();
                elseif remainingTime <= 0
                    % Only allow continue after countdown finishes
                    break;
                end
            end
        end
        KbReleaseWait();
    end
    
end  % End block loop

%======================================================================
%%                    EXPERIMENT COMPLETE
%======================================================================

Screen('FillRect', window, black);
Screen('TextSize', window, 32);
DrawFormattedText(window, 'Experiment Complete!\n\nThank you for participating.', ...
    'center', 'center', white);
Screen('Flip', window);

% Play success sounds: correcto followed by woohoo
try
    PsychPortAudio('Start', pahandle_correcto, 1, 0, 1);  % Wait for correcto to finish
    PsychPortAudio('Start', pahandle_woohoo, 1, 0, 1);    % Then play woohoo
catch
end

% Display completion message for 3 seconds (frame-based)
completionText = 'Experiment Complete!\n\nThank you for participating.';
for endFrame = 1:round(3 * refreshRate)
    Screen('FillRect', window, black);
    Screen('TextSize', window, 32);
    DrawFormattedText(window, completionText, 'center', 'center', white);
    Screen('Flip', window);
end

%----------------------------------------------------------------------
%%                    SAVE DATA (Final save - data already saved incrementally)
%----------------------------------------------------------------------

% Final save using the filepath established at session start
csv_table = cell2table(csv_data, 'VariableNames', csv_header);
writetable(csv_table, csv_filepath);
fprintf('\nData saved to: %s\n', csv_filepath);

% Print summary
fprintf('\n=== EXPERIMENT SUMMARY ===\n');
fprintf('Valid trials: %d\n', csv_trial_counter);
fprintf('Blocks completed: %d\n', numBlocks);
fprintf('Block order: ');
for i = 1:length(blockOrder)
    fprintf('%s ', conditionNames{blockOrder(i)});
end
fprintf('\n');

%----------------------------------------------------------------------
%%                    CLEANUP
%----------------------------------------------------------------------

if isEyelink
    Eyelink('StopRecording');
    Eyelink('CloseFile');
    try
        Eyelink('ReceiveFile', constants.eyelink_data_fname, constants.eyelink_data_path);
    catch
        fprintf('Warning: Could not retrieve EDF file\n');
    end
    Eyelink('Shutdown');
end

Priority(0);  % Reset priority to normal
PsychPortAudio('Close', pahandle_warning);
PsychPortAudio('Close', pahandle_tick);     % Close tick sound handle
PsychPortAudio('Close', pahandle_eyelink);  % Close Eyelink audio handle
% Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS  % Release cursor from experiment window
Screen('CloseAll');
ListenChar(0);  % Re-enable keyboard to MATLAB
ShowCursor;

% RESTORE macOS alert volume
try
    system(sprintf('osascript -e "set volume alert volume %d"', originalAlertVolume));
catch
    % If restoration fails, try setting to default
    system('osascript -e "set volume alert volume 100"');
end

fprintf('\nExperiment finished successfully!\n');

%======================================================================
%%                    HELPER FUNCTION: CONFIRM QUIT DIALOG
%======================================================================
function shouldQuit = confirmQuitDialog(window, white, grey, black)
    % Display confirmation dialog and return true if user confirms quit
    Screen('FillRect', window, black);
    Screen('TextSize', window, 32);
    DrawFormattedText(window, 'Are you sure you want to quit?\n\n [Y]      [N]', ...
        'center', 'center', white);
    Screen('Flip', window);
    
    KbReleaseWait();
    shouldQuit = false;
    waiting = true;
    while waiting
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown
            if keyCode(KbName('y'))
                shouldQuit = true;
                waiting = false;
            elseif keyCode(KbName('n')) || keyCode(KbName('ESCAPE'))
                shouldQuit = false;
                waiting = false;
            end
        end
    end
    KbReleaseWait();
end
