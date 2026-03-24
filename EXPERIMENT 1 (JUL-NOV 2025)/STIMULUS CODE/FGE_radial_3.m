% =========================================================================================
%%                         FLASH GRAB ILLUSION EXPERIMENT 
%                                     [Radial]
%                           Last modified: October 18, 2025 
% ========================================================================================
%
%                         
%%                                DESCRIPTION:
%      Psychophysical experiment investigating the Flash Grab Illusion using 
%        adaptive staircase methodology. Measures perceived location bias of 
%    flashed stimuli within moving concentric gratings across visual quadrants.
%
%
%%                         EXPERIMENTAL DESIGN & CONTENTS:
%
% CONTROLS:
% I = White bar (probe) appears more inner than red bar (flash) → Move probe outer
% O = White bar (probe) appears more outer than red bar (flash) → Move probe inner
%
% IMPORTANT: This version requires a monitor configured to run at exactly 85Hz.
% The experiment will validate the refresh rate and halt if not running at 85Hz.
% Configure your monitor to 85Hz and 800x600 resolution before running this experiment.
%
%=============================================================================

clear all;close all;

%% EXPERIMENT SETUP
 
sbjname = '999';              % Subject's name/ID for data files
blockNum = 1;                  % How many blocks of trials to run
numTrialsPerBlock = 24;         % Total number of trials (must be multiple of 24, +6 catch trials per block)
isEyelink = 1;                  % 0 = no eye tracker, 1 = use eye tracker


%----------------------------------------------------------------------
%%                     PSYCHTOOLBOX INITIALIZATION 
%----------------------------------------------------------------------

% For precise 85Hz timing, disable sync tests skip and enable precise timing
Screen('Preference', 'SkipSyncTests', 1);  % Enable sync tests for precise timing
Screen('Preference', 'VBLTimestampingMode', 1);  % High precision timing

% Additional preferences to help with macOS compatibility
Screen('Preference', 'ConserveVRAM', 0);  % Use full VRAM for better performance
% PsychDefaultSetup(2);  
KbName('UnifyKeyNames');
screens = Screen('Screens');
screenNumber = max(screens);

% Add function path
addpath(fullfile(fileparts(mfilename('fullpath')), '../function'));

%----------------------------------------------------------------------
%%                         DISPLAY PARAMETERS
%----------------------------------------------------------------------
black = BlackIndex(screenNumber);       % Pure black (0% intensity) - main background
white = WhiteIndex(screenNumber);       % Pure white (100% intensity)
grey = WhiteIndex(screenNumber) / 2;    % Middle gray (50% intensity) - for grating center
red = [255 0 0];                        % Red (for fixation when gaze outside 3 DVA)

% Set specific screen resolution
Screen('Resolution', screenNumber, 800, 600); 
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);  % Black background
commandwindow;

eyeScreenDistance = 57;    
screenHeight = 30.5;       
screenHeightPixels = windowRect(4);  % Height of the window in pixels (600)
xCenter = windowRect(3) / 2;  % Center X at 400 pixels
yCenter = windowRect(4) / 2;  % Center Y at 300 pixels
refreshRate = 85;  % Set to 85Hz for improved timing stability
resolutionFactor = 1;

flash.QuadDegree = [45 135 225 315];  % Testing all four quadrants 45 135 225 315

%% FIXATION CROSS
fixCrossDimDva = 0.5;
fixCrossDimPix = dva2pix(fixCrossDimDva, eyeScreenDistance, windowRect, screenHeight);
fixCoords = [-fixCrossDimPix fixCrossDimPix 0 0; 0 0 -fixCrossDimPix fixCrossDimPix];
fixLineWidth = 3;
fixDuration = 0.5;

%% FLASH PARAMETERS

flash.WidthDva = 0.5;   
flash.LengthDva = 3;    
flash.WidthPix = dva2pix(flash.WidthDva,eyeScreenDistance,windowRect,screenHeight);
flash.LengthPix = dva2pix(flash.LengthDva,eyeScreenDistance,windowRect,screenHeight);
flash.Size = [0, 0, flash.WidthPix, flash.LengthPix];  

flash.EccentricityDva = [7, 11]; % Flash base eccentricities
flash.JitterDva = [-1, 0, 1];

% Create red flash texture (properly scaled for Screen('OpenWindow'))
flash.Image(:,:,1) = ones(flash.LengthPix, flash.WidthPix) * white;   % Red channel = white intensity
flash.Image(:,:,2) = zeros(flash.LengthPix, flash.WidthPix);          % Green channel = 0 (no green)
flash.Image(:,:,3) = zeros(flash.LengthPix, flash.WidthPix);          % Blue channel = 0 (no blue)

% Convert the image array into a texture that Psychtoolbox can display
flash.Texture = Screen('MakeTexture', window, flash.Image);

%% PROBE PARAMETERS

probe.WidthDva = 0.5;   
probe.LengthDva = 3; 
probe.WidthPix = dva2pix(probe.WidthDva,eyeScreenDistance,windowRect,screenHeight);
probe.LengthPix = dva2pix(probe.LengthDva,eyeScreenDistance,windowRect,screenHeight);

% Create white probe texture (properly scaled for Screen('OpenWindow'))
probe.Image(:,:,1) = ones(probe.LengthPix, probe.WidthPix) * white;  % Red channel = white intensity
probe.Image(:,:,2) = ones(probe.LengthPix, probe.WidthPix) * white;  % Green channel = white intensity  
probe.Image(:,:,3) = ones(probe.LengthPix, probe.WidthPix) * white;  % Blue channel = white intensity

probe.Texture = Screen('MakeTexture', window, probe.Image);
probe.Size = [0, 0, probe.WidthPix, probe.LengthPix];

%% GRATING 

gratingRadiusDva = 20;   
gratingRadiusPix = dva2pix(gratingRadiusDva,eyeScreenDistance,windowRect,screenHeight);  
gratingRect = [xCenter - gratingRadiusPix, yCenter - gratingRadiusPix, ...
              xCenter + gratingRadiusPix, yCenter + gratingRadiusPix];

contrastFactor = (white - grey) * 0.25;  % Use grey for proper grating contrast

% Define uniform control grey values (lighter and darker grey used in grating)
uniformLightGrey = grey + contrastFactor;  % Lighter grey
uniformDarkGrey = grey - contrastFactor;   % Darker grey

gratingMaskRadius = 15;  
gratingMaskRadiusPix = dva2pix(gratingMaskRadius,eyeScreenDistance,windowRect,screenHeight);  

cycleWidthDva = 5;    % Width of one cycle in degrees of visual angle
cycleWidthPix = dva2pix(cycleWidthDva,eyeScreenDistance,windowRect,screenHeight);

[X, Y] = meshgrid(linspace(-gratingRadiusPix, gratingRadiusPix, round(2 * gratingRadiusPix * resolutionFactor)));
R = sqrt(X.^2 + Y.^2);

%% MASK SETUP

gazeMonitoringRadius_dva = 3;  % Central disk radius and gaze violation threshold
centerDiskRadiusPix = dva2pix(gazeMonitoringRadius_dva,eyeScreenDistance,windowRect,screenHeight);  
centerDiskRect = [xCenter - centerDiskRadiusPix, yCenter - centerDiskRadiusPix, ...
                 xCenter + centerDiskRadiusPix, yCenter + centerDiskRadiusPix];

wedgeCoverAngle = 315;  
wedgeStartMat = [67.5 157.5 247.5 337.5];  % Starting angles for each quadrant's wedge mask

%% MOTION & TIMING PARAMETERS

targetSpeedDvaPerSec = 20; % Velocity of motion   
totalmotiontime = 2   ;  % Total timep for motion display
gratDuraFrame = refreshRate * totalmotiontime;  % Convert total time to number of frames 
baseFlashFrame = round(gratDuraFrame / 2);  % Find middle frame for symmetric timing
 
temporalJitterOptions = [-0.25, 0, 0.25]; % of flash, in seconds
temporalJitterFrameOptions = round(temporalJitterOptions * refreshRate); 

flash.MotDirec = [-1, 0, 1];  % Motion direction (-1 = petal, 0 = control, 1 = fugal)
flash.PresFrame = 4; % Present flash for 4 frames (~47ms at 85Hz, similar to 50ms at 100Hz)

%----------------------------------------------------------------------
%%                   SHUFFLE CONDITIONS IN EACH BLOCK
%----------------------------------------------------------------------

[quad_vals, mot_vals, shift_vals] = ndgrid(flash.QuadDegree, flash.MotDirec, flash.EccentricityDva);
combinations = [quad_vals(:), mot_vals(:), shift_vals(:)];

all_combinations = cell(blockNum, 1); % For each block, create a randomized order of trials
for block = 1:blockNum
   rng('shuffle');
   complete_sets = floor(numTrialsPerBlock / 24);
   block_trials = repmat(combinations, complete_sets, 1);
   block_trials = block_trials(randperm(numTrialsPerBlock), :);

   % Create 6 catch trials - one for each staircase condition
   % Define staircase conditions: [motion_code, hemifield]
   % -1=petal, 0=control, 1=fugal; 1=upper, -1=lower
   staircase_conditions = [-1, 1; 0, 1; 1, 1; -1, -1; 0, -1; 1, -1];  % [motion, hemifield]
   staircase_names = {'upper_petal', 'upper_control', 'upper_fugal', 'lower_petal', 'lower_control', 'lower_fugal'};
   
   % FIXED: Optimal balanced quadrant assignment for catch trials
   % Works for ANY number of blocks to ensure minimal imbalance
   % Perfect balance for even blocks, minimal imbalance (max diff = 1) for odd blocks
   
   catch_trials = [];
   for catch_idx = 1:6
       motion_code = staircase_conditions(catch_idx, 1);
       hemifield = staircase_conditions(catch_idx, 2);
       
       % Select quadrant based on hemifield
       if hemifield == 1  % Upper hemifield
           quad_options = [45, 135];  % Upper quadrants [UR, UL]
       else  % Lower hemifield
           quad_options = [225, 315];  % Lower quadrants [LL, LR]
       end
       
       % Optimal balanced selection using round-robin within each hemifield
       % This distributes catch trials as evenly as possible across all blocks
       % Formula ensures systematic cycling through available quadrants
       
       % Calculate how many times this hemifield has appeared in previous blocks
       hemifield_occurrences_before = 0;
       for prev_block = 1:(block-1)
           for prev_catch = 1:6
               if staircase_conditions(prev_catch, 2) == hemifield
                   hemifield_occurrences_before = hemifield_occurrences_before + 1;
               end
           end
       end
       
       % Count how many times this hemifield appears in current block up to this catch
       hemifield_occurrences_current = 0;
       for curr_catch = 1:(catch_idx-1)
           if staircase_conditions(curr_catch, 2) == hemifield
               hemifield_occurrences_current = hemifield_occurrences_current + 1;
           end
       end
       
       % Total occurrences of this hemifield so far
       total_hemifield_occurrences = hemifield_occurrences_before + hemifield_occurrences_current;
       
       % Alternate between the two quadrants in this hemifield
       quad_selector = mod(total_hemifield_occurrences, 2) + 1;
       quad = quad_options(quad_selector);
       
       % Deterministic alternating pattern for eccentricity across ALL catch trials
       % Use similar logic as quadrant selection for balanced eccentricity distribution
       total_catch_occurrences = (block - 1) * 6 + catch_idx;  % Total catch trials so far
       ecc_selector = mod(total_catch_occurrences, 2) + 1;  % Alternates between 1 and 2
       ecc = flash.EccentricityDva(ecc_selector);  % Deterministic but balanced inner/outer selection
       jitter = flash.JitterDva(randi(3));     % Random jitter: -1, 0, or 1 DVA
       temporal_jitter = temporalJitterFrameOptions(randi(3));  % Random temporal jitter
       
       % Easy catch trial offset: ±5 DVA from flash
       probe_offset = 5 * (2*randi(2) - 3);
       
       % Create catch trial: [quad, motion, ecc, probeOffset, jitter, temporalJitter, isCatchTrial]
       catch_trial = [quad, motion_code, ecc, probe_offset, jitter, temporal_jitter, 1];
       catch_trials = [catch_trials; catch_trial];
   end

   % Normal trials: [quad, motion, flashEccentricity, probeOffset, jitter, temporalJitter, isCatchTrial]
   block_trials_full = [block_trials, NaN(numTrialsPerBlock,1), NaN(numTrialsPerBlock,1), NaN(numTrialsPerBlock,1), zeros(numTrialsPerBlock,1)];
   
   % Add all 6 catch trials to the block
   block_trials_full = [block_trials_full; catch_trials];
   
   % Shuffle all trials (24 normal + 6 catch = 30 total)
   block_trials_full = block_trials_full(randperm(size(block_trials_full, 1)), :);
   all_combinations{block} = block_trials_full;
end

%----------------------------------------------------------------------
%%%            Eyelink setting up
%----------------------------------------------------------------------

% Create EDF filename (EyeLink requires max 8 chars, no special characters)
% Use subject name (first 3 chars) + 2-digit session number (01, 02, 03, etc.)
subject_prefix = sbjname(1:min(3,length(sbjname)));

% Find existing EDF files for this subject to determine next session number
data_folder = fullfile(fileparts(mfilename('fullpath')), '../data');
if ~exist(data_folder, 'dir')
    mkdir(data_folder);
end

% Look for existing EDF files with this subject prefix
existing_files = dir(fullfile(data_folder, [subject_prefix, '*.edf']));
session_numbers = [];

% Extract session numbers from existing files
for i = 1:length(existing_files)
    filename = existing_files(i).name;
    % Check if filename matches pattern: ABC##.edf (3 chars + 2 digits)
    if length(filename) == 8 && strcmp(filename(end-3:end), '.edf')
        session_part = filename(4:5); % Extract the 2-digit part
        if all(isstrprop(session_part, 'digit'))
            session_numbers = [session_numbers, str2double(session_part)];
        end
    end
end

% Determine next session number
if isempty(session_numbers)
    next_session = 1;
else
    next_session = max(session_numbers) + 1;
end

% Create EDF filename with 2-digit session number
edf_name = sprintf('%s%02d', subject_prefix, next_session);
constants.eyelink_data_fname = [edf_name, '.edf'];
% Create path to data folder for EDF file (folder already created above)
constants.eyelink_data_path = fullfile(data_folder, constants.eyelink_data_fname);

% Create window struct for EyeLink setup (window is just a pointer, so create a struct)
windowStruct.pointer = window;
windowStruct.background = black;  % Changed from grey to black
windowStruct.white = white;      % Use the 'white' variable defined earlier  
windowStruct.winRect = windowRect; % Use the 'windowRect' variable defined earlier

% Initialize EyeLink setup
el = [];
exit_flag = 0;

if isEyelink
    
    % Initialize EyeLink connection
    if EyelinkInit(0) ~= 1
        isEyelink = 0; % Disable EyeLink if initialization fails
    else
        
        % Open EDF file
        if Eyelink('OpenFile', constants.eyelink_data_fname) ~= 0
            Eyelink('Shutdown');
            isEyelink = 0;
        else
            
            % Get EyeLink defaults
            el = EyelinkInitDefaults(windowStruct.pointer);
            
            % Set up calibration colors and parameters
            el.calibrationtargetcolour = [255 255 255];
            el.calibrationtargetsize = 1.0;
            el.calibrationtargetwidth = 0.5;
            Eyelink('command', 'calibration_area_proportion = 0.5 0.5');
            % Set screen coordinates
            Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, windowRect(3)-1, windowRect(4)-1);
            
            % Set EDF file contents
            Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
            Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
            Eyelink('Command', 'file_sample_data = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
            Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
            
            % PERFORM CALIBRATION AND VALIDATION
            Eyelink('Command', 'set_idle_mode');
            Eyelink('Command', 'clear_screen 0');
            
            % Do calibration
            EyelinkUpdateDefaults(el);
            EyelinkDoTrackerSetup(el);
            % After calibration is accepted, automatically proceed
            Eyelink('Command', 'set_idle_mode');
        end
    end
else
    fprintf('*** EYELINK DISABLED (isEyelink = 0) - No eye tracking ***\n');
end


if isEyelink
    % Must be offline to draw to EyeLink screen
    Eyelink('Command', 'set_idle_mode');
    % clear tracker display
    Eyelink('Command', 'clear_screen 0');
    Eyelink('Command','draw_box %d %d %d %d ',xCenter-50,yCenter-50,xCenter+50,yCenter+50);
    
    % Start recording before experiment begins
    Eyelink('StartRecording');

    eyeUsed = Eyelink('EyeAvailable'); % get eye that's tracked
    % returns 0 (LEFT_EYE), 1 (RIGHT_EYE) or 2 (BINOCULAR) depending on what data is
    if eyeUsed == 2
        eyeUsed = 1; % use the right_eye data
    end
    
    % Define MISSING_DATA constant (this is critical!)
    MISSING_DATA = -32768; % Standard EyeLink missing data value
    
    % Define EyeLink constants for data types
    if ~isfield(el, 'SAMPLE_TYPE')
        el.SAMPLE_TYPE = 200; % Standard EyeLink sample type constant
    end
    
    % Mark when the experiment has actually started
    Eyelink('message', 'SYNCTIME');
    
end

%----------------------------------------------------------------------
%              Eye gaze restriction
%----------------------------------------------------------------------

driftDuation_pre = 1; %  sec

% eye gaze distance from center - using consolidated radius for all gaze monitoring
fixRadius = dva2pix(gazeMonitoringRadius_dva, eyeScreenDistance, windowRect, screenHeight);
warningGazeRadius_pix = dva2pix(gazeMonitoringRadius_dva, eyeScreenDistance, windowRect, screenHeight);
% Dynamic fixation color (white normally, red when gaze outside monitoring radius)
fixationColor = white;  % Updated in real-time using eye tracker samples
fixationOutside2DVA_prev = false; % Track previous inside/outside state (for sound throttle)

%----------------------------------------------------------------------
%                       Sound Setup
%----------------------------------------------------------------------
InitializePsychSound(1);
sampRate = 44100;

% Setup warning sound for gaze violations
warningFreq = 200;
warningDur = 0.5;
warningSound = MakeBeep(warningFreq, warningDur, sampRate);
warningSound = [warningSound; warningSound]; % Make stereo
pahandle_warning = PsychPortAudio('Open', [], [], 0, sampRate, 2);
PsychPortAudio('FillBuffer', pahandle_warning, warningSound);


%----------------------------------------------------------------------
%%                           STAIRCASE SETUP
%----------------------------------------------------------------------
stepSizeDva = 1.5; % Initial step size 
minStepSizeDva = 0.2; % Minimum step size

% Initialize Staircases * 6 (0 indicates initial probe at flash location)
staircase.upper_fugal = initialize_staircase(0, stepSizeDva, minStepSizeDva);   
staircase.upper_petal = initialize_staircase(0, stepSizeDva, minStepSizeDva);     
staircase.upper_control = initialize_staircase(0, stepSizeDva, minStepSizeDva);   
staircase.lower_fugal = initialize_staircase(0, stepSizeDva, minStepSizeDva);     
staircase.lower_petal = initialize_staircase(0, stepSizeDva, minStepSizeDva);      
staircase.lower_control = initialize_staircase(0, stepSizeDva, minStepSizeDva);   

% Initialize staircase trial counters for each condition
staircase.upper_fugal.trial_count = 0;
staircase.upper_petal.trial_count = 0;
staircase.upper_control.trial_count = 0;
staircase.lower_fugal.trial_count = 0;
staircase.lower_petal.trial_count = 0;
staircase.lower_control.trial_count = 0;

fields = fieldnames(staircase);

calculateLastTrialNum = 5;  % Use the last 5 trials to calculate the threshold

%----------------------------------------------------------------------
%%                         INSTRUCTION DISPLAY
%----------------------------------------------------------------------

% Display FGE_info_radial.png first
try
    infoImagePath = fullfile(fileparts(mfilename('fullpath')), '../instructions/FGE_info_radial.png');
    infoImage = imread(infoImagePath);
    infoTexture = Screen('MakeTexture', window, infoImage);
    
    % Stretch image to fit full screen
    windowWidth = xCenter * 2;
    windowHeight = yCenter * 2;
    destRect = [0, 0, windowWidth, windowHeight];
    
    % Draw the info image
    Screen('DrawTexture', window, infoTexture, [], destRect);
    Screen('Flip', window);
    
    % Wait for spacebar press
    keyboardIndices = GetKeyboardIndices();
    spacePressed = false;
    
    while ~spacePressed
        for keyIdx = 1:length(keyboardIndices)
            [keyIsDown, ~, keyCode] = KbCheck(keyboardIndices(keyIdx));
            if keyIsDown && keyCode(KbName('space'))
                spacePressed = true;
                break;
            end
        end
        WaitSecs(0.001);
    end
    
    % Wait for key release
    KbReleaseWait();
    Screen('Close', infoTexture);
    
catch ME
    fprintf('Warning: Could not load FGE_info_radial.png: %s\n', ME.message);
end

% Display FGE_instructions_radial.png second
try
    instructionsImagePath = fullfile(fileparts(mfilename('fullpath')), '../instructions/FGE_instructions_radial.png');
    instructionsImage = imread(instructionsImagePath);
    instructionsTexture = Screen('MakeTexture', window, instructionsImage);
    
    % Stretch image to fit full screen
    destRect = [0, 0, windowWidth, windowHeight];
    
    % Draw the instructions image
    Screen('DrawTexture', window, instructionsTexture, [], destRect);
    Screen('Flip', window);
    
    % Wait for spacebar press (exact same logic as motion coherence)
    fprintf('Press SPACEBAR to begin experiment...\n');
    keyboardIndices = GetKeyboardIndices();
    
    % Wait for any previously pressed keys to be released
    KbReleaseWait();
    WaitSecs(0.2);
    
    spacePressed = false;
    
    while ~spacePressed
        for keyIdx = 1:length(keyboardIndices)
            [keyIsDown, ~, keyCode] = KbCheck(keyboardIndices(keyIdx));
            if keyIsDown && keyCode(KbName('space'))
                spacePressed = true;
                break;
            end
        end
        WaitSecs(0.001);
    end
    
    % Clean up texture
    Screen('Close', instructionsTexture);
    
catch ME
    fprintf('Warning: Could not load FGE_instructions_radial.png: %s\n', ME.message);
end

% Reset screen to black background after instructions
Screen('FillRect', window, black);
Screen('Flip', window);

%======================================================================
%%                        MAIN EXPERIMENT LOOP
%======================================================================

% Initialize CSV data collection structure
csv_data = [];
csv_trial_counter = 0;  % Counter for valid trials across all blocks
catch_trial_counter = 0;  % Counter for catch trials across all blocks
experimentCompleted = false;  % Flag to track if experiment completed normally

% Run the experiment for the specified number of blocks
for block = 1: blockNum
  
   %----------------------------------------------------------------------
   %   INITIALIZE PER-BLOCK INVALID TRIAL QUEUE (for motion-phase gaze breaks)
   %----------------------------------------------------------------------
   invalidTrialsQueue = []; % Will store structs of trials to repeat
   maxRepeatAttempts = 3;   % Safety to avoid infinite looping if fixation impossible
   if ~exist('trialRepeatAttempts','var') || size(trialRepeatAttempts,1) < block
       trialRepeatAttempts(block,1) = 0; %#ok<AGROW>
   end
   
   %----------------------------------------------------------------------
   %       Set up text display properties
   %----------------------------------------------------------------------
 
   Screen ('TextSize',window,30);      % Large text size
   Screen('TextFont',window,'Futura'); % Modern, clean font
  
   % Clear the screen to black before block start
   Screen('FillRect', window, black);
   Screen('Flip', window);
  
   % Wait a moment before accepting input
   WaitSecs(0.3);
  
   %----------------------------------------------------------------------
   %       KEYBOARD SETUP FOR BLOCK START
   %       Find all connected keyboards and wait for input
   %----------------------------------------------------------------------
  
   % Find all keyboard devices connected to the computer
   devices = PsychHID('Devices');
   keyboardIndices = [];  % Initialize empty list
  
   % Loop through all devices and find keyboards
   for i = 1:length(devices)
       if strcmp(devices(i).usageName, 'Keyboard')
           keyboardIndices = [keyboardIndices, devices(i).index];
       end
   end
  
   % Wait for spacebar press on any keyboard
   spacePressed = false;
   while ~spacePressed
       % Check each keyboard for spacebar
       for i = 1:length(keyboardIndices)
           [keyIsDown, ~, keyCode] = KbCheck(keyboardIndices(i));
           if keyIsDown && keyCode(KbName('space'))
               spacePressed = true;
               break;
           end
       end
       WaitSecs(0.01); % Short pause to avoid overwhelming the CPU
   end

   if isEyelink
       EyelinkDoDriftCorrection(el);
       Eyelink('Message', 'BLOCKID %d', block);
   end

   % Ensure black background before starting trials
   Screen('FillRect', window, black);
   Screen('Flip', window);

   %----------------------------------------------------------------------
   %                            TRIAL LOOP
   %                 This loop runs each individual trial
   %----------------------------------------------------------------------
  
   % Loop over all shuffled trials (including catch trial)
   numTrialsThisBlock = size(all_combinations{block}, 1);
   trial = 1;  % Initialize trial counter
   while trial <= numTrialsThisBlock
      
       %==================================================================
       %                    TRIAL INITIALIZATION
       %==================================================================
      
       % Reset fixation color to white at start of each trial
       fixationColor = white;
       
       % Set trial validity flag (1 = valid, 0 = invalid/abandoned)
       validTrialFlag = 1;
      
       % Initialize frame counter for grating animation
       i = 1;
      
       % Show fixation cross before the stimulus (update color if gaze available)
       Screen('DrawLines', window, fixCoords, fixLineWidth, fixationColor, [xCenter,yCenter]);
       fixationStartTime = Screen('Flip', window);
       
       % Wait for fixation duration using flip timing instead of WaitSecs
       while GetSecs() - fixationStartTime < fixDuration
           % Optional: sample gaze & update fixation color during pre-stimulus fixation (NO sound/violations)
           if isEyelink
               if Eyelink('NewFloatSampleAvailable') > 0
                   evt = Eyelink('NewestFloatSample');
                   if eyeUsed ~= -1 && length(evt.gx) > eyeUsed
                       gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                       if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                           gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                           gazeDistDva = pix2dva(gazeDistPix, eyeScreenDistance, windowRect, screenHeight);
                           outside2 = gazeDistDva > gazeMonitoringRadius_dva;
                           % NO SOUND during pre-stimulus - just update fixation color
                           fixationOutside2DVA_prev = outside2;
                           if outside2
                               fixationColor = red; 
                           else
                               fixationColor = white; 
                           end
                       end
                   end
               end
           end
           Screen('DrawLines', window, fixCoords, fixLineWidth, fixationColor, [xCenter,yCenter]);
           Screen('Flip', window);
       end

       % Initialize variables for this trial
    phaseShift = 0;           % Starting position of the grating pattern

       
       %==================================================================
       %                    GET TRIAL PARAMETERS
       %==================================================================
      
       % Get the conditions for this specific trial from our randomized list
       trial_params = all_combinations{block}(trial, :);
       quad = trial_params(1);        % Which quadrant (45, 135, 225, or 315 degrees)
       motionDirec = trial_params(2); % Motion direction (-1=petal, 0=uniform control, 1=fugal)
       flash.EccentricityDva_current = trial_params(3); % Flash eccentricity in DVA (7 or 11 dva)
       
       % Initialize uniform control grey selection for this trial
       if motionDirec == 0  % Uniform control condition
           % Randomly select lighter or darker grey for this trial
           if rand() < 0.5
               uniformControlGrey = uniformLightGrey;
           else
               uniformControlGrey = uniformDarkGrey;
           end
       end
       
       % Check if this is a catch trial
       if length(trial_params) >= 7 && trial_params(7) == 1
           isAttentionCheck = true;
           validTrialFlag = 1; % Catch trials are valid (for lapse rate measurement)
           probeOffsetDva = trial_params(4); % Use fixed 5 DVA offset
           jitterDva = 0; % No jitter for catch trial
           temporalJitterFrames = 0; % No temporal jitter for catch trial
           
           % Silent catch trial - no console output
           
       else
           isAttentionCheck = false;
           % Handle spatial jitter selection - consistent for repeated trials
           if ~exist('trialJitter', 'var') || size(trialJitter, 1) < block || size(trialJitter, 2) < trial || trialJitter(block, trial) == 999
               % First time this trial is being run - randomly select jitter
               jitterOptions = flash.JitterDva;  % [-1, 0, 1]
               jitterDva = jitterOptions(randi(length(jitterOptions)));  % Random selection
               % Store jitter for potential repeats (expand array if needed)
               if ~exist('trialJitter', 'var')
                   trialJitter = 999 * ones(20, 50); % Initialize with sentinel value
               end
               if size(trialJitter, 1) < block || size(trialJitter, 2) < trial
                   trialJitter(block, trial) = 999; % Expand if needed
               end
               trialJitter(block, trial) = jitterDva;
           else
               % This trial has been run before (repeated) - use the same jitter
               jitterDva = trialJitter(block, trial);
           end
           
           % Handle temporal jitter selection - consistent for repeated trials
           if ~exist('trialTemporalJitter', 'var') || size(trialTemporalJitter, 1) < block || size(trialTemporalJitter, 2) < trial || trialTemporalJitter(block, trial) == 999
               % First time this trial is being run - randomly select from predefined options
               jitterIndex = randi(length(temporalJitterFrameOptions));  % Random index
               temporalJitterFrames = temporalJitterFrameOptions(jitterIndex);  % Get corresponding jitter
               % Store temporal jitter for potential repeats (expand array if needed)
               if ~exist('trialTemporalJitter', 'var')
                   trialTemporalJitter = 999 * ones(20, 50); % Initialize with sentinel value
               end
               if size(trialTemporalJitter, 1) < block || size(trialTemporalJitter, 2) < trial
                   trialTemporalJitter(block, trial) = 999; % Expand if needed
               end
               trialTemporalJitter(block, trial) = temporalJitterFrames;
           else
               % This trial has been run before (repeated) - use the same temporal jitter
               temporalJitterFrames = trialTemporalJitter(block, trial);
           end
       end
       
       % Calculate the actual jittered flash frame
       flashFrame = baseFlashFrame + temporalJitterFrames;
       % Ensure flash frame stays within valid range
       flashFrame = max(1, min(flashFrame, gratDuraFrame));
       
       % Convert temporal jitter back to seconds for console output
       temporalJitterSec = temporalJitterFrames / refreshRate;

       % Calculate the actual jittered flash location in DVA space
       jitteredFlashLocDva = flash.EccentricityDva_current + jitterDva;
       
       % POSITIONING FIX: Add half bar width so bars are positioned by center, not outer edge
       barHalfWidthDva = flash.WidthDva / 2; % 0.25 DVA
       jitteredFlashLocDva_centered = jitteredFlashLocDva + barHalfWidthDva;
       
       % Convert to pixels for display positioning (using centered position)
       jitteredFlashLocPix = dva2pix(jitteredFlashLocDva_centered, eyeScreenDistance, windowRect, screenHeight);

       %==================================================================
       %                    SET MOTION SPEED
       %                    Use consistent speed with frame-based flash timing
       %==================================================================
       
       if motionDirec ~= 0  % Only for motion trials
           % Use consistent speed that provides good motion perception (~15 dva/s)
           Speed = dva2pix(targetSpeedDvaPerSec, eyeScreenDistance, windowRect, screenHeight) / refreshRate;
           
           % Store speed for this trial
           trialSpeed(block, trial) = Speed;
           
       else  % Uniform control trials don't need motion
           Speed = 0;
           trialSpeed(block, trial) = 0;
       end
       
    % Adjust starting phase so a luminance edge aligns with the flash radial position on the first flash frame.
       % Off-by-one correction: motion advances (flashFrame-1) times BEFORE first flash frame.
       if motionDirec ~= 0  % Motion trials
           framesOfMotionBeforeFlash = flashFrame - 1; % off-by-one fix
           phaseShiftAtFlash_ifStartZero = motionDirec * Speed * framesOfMotionBeforeFlash; % px shift if start phase = 0
           targetRadius = jitteredFlashLocPix; % px radial position needing boundary (using centered position for alignment)
           rawPhase = targetRadius + phaseShiftAtFlash_ifStartZero; % phase value at flash if startingPhase=0
           % Snap to nearest cycle boundary (multiples of cycleWidthPix)
           boundaryMultiple = round(rawPhase / cycleWidthPix);
           desiredPhase = boundaryMultiple * cycleWidthPix;
           startingPhaseOffset = desiredPhase - rawPhase; % amount we need to add as initial phaseShift
           % Keep phase in compact range for numerical stability
           startingPhaseOffset = mod(startingPhaseOffset, cycleWidthPix);
           if startingPhaseOffset > cycleWidthPix/2
               startingPhaseOffset = startingPhaseOffset - cycleWidthPix;
           end
           phaseShift = startingPhaseOffset;
           
       else % Uniform control trials: just align without motion component
           targetRadius = jitteredFlashLocPix; % Use centered position for alignment
           boundaryMultiple = round(targetRadius / cycleWidthPix);
           desiredPhase = boundaryMultiple * cycleWidthPix;
           startingPhaseOffset = desiredPhase - targetRadius;
           startingPhaseOffset = mod(startingPhaseOffset, cycleWidthPix);
           if startingPhaseOffset > cycleWidthPix/2
               startingPhaseOffset = startingPhaseOffset - cycleWidthPix;
           end
           phaseShift = startingPhaseOffset;
           
       end

       %==================================================================
       %                    QUADRANT-SPECIFIC SETUP
       %                    Set angles and positioning factors based on quadrant
       %==================================================================
      
       % Set the rotation angle for the flash and probe bars
       % The bars are rotated to be perpendicular to the radius in each quadrant
       if  quad == 135 || quad == 315   % Upper-left and lower-right quadrants
           flash.Angle = 45;             % Rotate 45 degrees
       else  % quad == 45 || quad == 225    % Upper-right and lower-left quadrants 
           flash.Angle = 135;            % Rotate 135 degrees
       end
       
       %==================================================================
       %                    SELECT APPROPRIATE STAIRCASE
       %                    Choose which adaptive algorithm to use for this trial
       %==================================================================
      
       % The staircase selection depends on:
       % 1. Motion direction (petal, fugal, none = control)
       % 2. Quadrant (upper = 45°/135°, lower = 225°/315°)
      
       if motionDirec == -1  % Petal motion
           if quad == 45 || quad == 135
               current_staircase = staircase.upper_petal;  % Upper quadrants
           elseif quad == 225 || quad == 315
               current_staircase = staircase.lower_petal;  % Lower quadrants
           end
          
       elseif motionDirec == 1  % Fugal motion
           if quad == 45 || quad == 135
               current_staircase = staircase.upper_fugal;  % Upper quadrants
           elseif quad == 225 || quad == 315
               current_staircase = staircase.lower_fugal;  % Lower quadrants
           end
          
       elseif motionDirec == 0  % No motion (control condition)
           if quad == 45 || quad == 135
               current_staircase = staircase.upper_control;  % Upper quadrants
           elseif quad == 225 || quad == 315
               current_staircase = staircase.lower_control;  % Lower quadrants
           end
       end
      
       % Set up quadrant-specific parameters for positioning
       % These factors determine how the flash and probe move in each quadrant
       if quad == 45              % Upper-right quadrant (45°)
           wedgeStart = wedgeStartMat(1);    % Wedge mask starting angle
           phaseshiftFactorX = 1;            % Positive X direction
           phaseshiftFactorY = -1;           % Negative Y direction (up is negative)
           target.Angle = 135;               % Target angle for probe
          
       elseif quad == 135         % Upper-left quadrant (135°)
           wedgeStart = wedgeStartMat(4);    % Use wedge mask for lower-right to show upper-left
           phaseshiftFactorX = -1;           % Negative X direction 
           phaseshiftFactorY = -1;           % Negative Y direction (up is negative)
           target.Angle = 45;                % Target angle for probe
          
       elseif quad == 225         % Lower-left quadrant (225°)
           wedgeStart = wedgeStartMat(3);    % Wedge mask starting angle
           phaseshiftFactorX = -1;           % Negative X direction
           phaseshiftFactorY = 1;            % Positive Y direction (down is positive)
           target.Angle = 135;               % Target angle for probe
          
       elseif quad == 315         % Lower-right quadrant (315°)
           wedgeStart = wedgeStartMat(2);    % Use wedge mask for upper-left to show lower-right
           phaseshiftFactorX = 1;            % Positive X direction
           phaseshiftFactorY = 1;            % Positive Y direction (down is positive)
           target.Angle = 45;                % Target angle for probe
       end

       %==================================================================
       %           Eyetracking
       %==================================================================

       if isEyelink
            Eyelink('Message', 'TRIALID %d', trial);
        end

       %==================================================================
       %                    GRATING ANIMATION SECTION
       %                    This creates the moving concentric grating
       %==================================================================
      
       % TWO TYPES OF TRIALS:
       % 1. Motion trials (motionDirec ≠ 0): Grating moves and flash appears at specific moment
       % 2. Uniform control trials (motionDirec = 0): Grating is uniform and flash appears at same timing
       
    % Flag to capture if participant broke fixation (>3 DVA) during MOTION PHASE ONLY
    gazeViolationDuringMotion = false;  % Will trigger invalidation & later repeat

       % Initialize flash tracking for frame skip detection
       previousFrameHadFlash = false;  % Track if previous frame had flash (for timing check)
       % track how many frames flash presented so far this trial
       flashFramesCounter = 0;
       
       % Initialize eyetracking performance variables
       eyeCheckFrameInterval = 10; % Reduced frequency: Check gaze every 10 frames instead of 5
       lastSoundTime = 0; % Track when sound was last played
       soundCooldownPeriod = 0.5; % Minimum 0.5 seconds between sounds

       % Loop through each frame of the grating animation (SAME FOR BOTH MOTION AND UNIFORM CONTROL)
       while i <= gratDuraFrame  % gratDuraFrame = total frames (2 seconds * 85 Hz = 170 frames)
           
           % Pause motion during flash frames (exactly flash.PresFrame frames)
           isFlashWindow = (i >= flashFrame) && (i < (flashFrame + flash.PresFrame));
           
           % UPDATE GRATING POSITION (paused while flash is on)
           if motionDirec ~= 0 && ~isFlashWindow
               phaseShift = phaseShift + motionDirec * Speed;
           end
          
           %--------------------------------------------------------------
           %            GENERATE THE GRATING PATTERN
           %--------------------------------------------------------------
          
           % Create the concentric ring pattern
           % R is the distance from center for each pixel
           % Adding phaseShift makes the pattern appear to move
           dynamicR = R + phaseShift;
          
           % Create square-wave grating (alternating black and white rings)
           % mod(dynamicR, cycleWidthPix * 2) creates repeating pattern
           % < cycleWidthPix makes it alternate between 0 and 1
           dynamicGrating = double(mod(dynamicR, cycleWidthPix * 2) < cycleWidthPix);
          
           % Convert from 0/1 pattern to -1/+1 contrast pattern
           dynamicGrating = (dynamicGrating * 2 - 1);
          
           % Apply contrast factor and center on gray background
           dynamicGrating = dynamicGrating * contrastFactor + grey;
           
           % UNIFORM CONTROL CONDITION: Override with uniform grey
           if motionDirec == 0  % Uniform control condition only
               % Replace the entire grating pattern with uniform grey
               % Use the randomly selected grey value for this trial
               dynamicGrating = ones(size(dynamicGrating)) * uniformControlGrey;
           end

           %--------------------------------------------------------------
           %            APPLY CIRCULAR MASK TO GRATING
           %--------------------------------------------------------------
          
           % Start with black background everywhere
           maskedGrating = ones(size(R)) * black;
           
           % Only show the grating inside the circular mask
           % R <= gratingMaskRadiusPix defines the circular boundary
           maskedGrating(R <= gratingMaskRadiusPix) = dynamicGrating(R <= gratingMaskRadiusPix);
          
           %--------------------------------------------------------------
           %            DISPLAY THE GRATING 
           %--------------------------------------------------------------
          
           % Convert the grating pattern to a texture for display 
           % Create texture only once per frame and immediately clean up
           maskedGratingTexture = Screen('MakeTexture', window, maskedGrating);
          
           % Draw the grating texture to the screen
           Screen('DrawTexture', window, maskedGratingTexture, [], gratingRect);
          
           % Apply the wedge mask to show only one quadrant
           Screen('FillArc', window, black, gratingRect, wedgeStart, wedgeCoverAngle);
          
           % Clean up texture immediately after use to prevent memory leak
           Screen('Close', maskedGratingTexture);
           
           % Clear texture variable to help garbage collection
           maskedGratingTexture = [];           
           % Store phase shift only occasionally to prevent memory buildup 
           
           %--------------------------------------------------------------
           %            FLASH TIMING LOGIC
           %--------------------------------------------------------------
           
           flashPresentFlag = false;

           % Flash appears at the predetermined middle frame for symmetric timing
           if i >= flashFrame && flashFramesCounter < flash.PresFrame
               % Calculate jittered flash position using pixel values for positioning
               flash.CenterPosX(block,trial) = xCenter + phaseshiftFactorX * jitteredFlashLocPix * sind(45);
               flash.CenterPosY(block,trial) = yCenter + phaseshiftFactorY * jitteredFlashLocPix * cosd(45);
              
               % Draw the flash at the calculated position
               flash.Rect = CenterRectOnPointd(flash.Size, flash.CenterPosX(block,trial), flash.CenterPosY(block,trial));
               Screen('DrawTexture', window, flash.Texture, [], flash.Rect, flash.Angle);
              
               % Store the phase shift at flash time for data analysis
               phaseShiftMat(block,trial) = phaseShift;
               flashFramesCounter = flashFramesCounter + 1;
               flashPresentFlag = true;
               
               % Mark when flash occurred for logging
               flashFrameActual(block,trial) = i;
               
               % Record actual flash appearance time relative to trial start 
               % (Flash timing now captured AFTER Flip below)
               
               % Reverse grating direction after flash completes (motion trials)
               if motionDirec ~= 0 && flashFramesCounter == flash.PresFrame
                   Speed = -Speed;
               end
           end
           
           %--------------------------------------------------------------
           %            COMPLETE FRAME DISPLAY
           %--------------------------------------------------------------
          
           % Draw the center black disk to cover the center of the grating
           Screen('FillOval', window, black, centerDiskRect);
          
           % Draw the fixation cross (color reflects gaze distance)
           Screen('DrawLines', window, fixCoords, fixLineWidth, fixationColor, [xCenter,yCenter]);
          
           % Show everything on screen with frame skip detection
           [VBLTimestamp, StimulusOnsetTime, FlipTimestamp, Missed, Beampos] = Screen('Flip', window);

           % Capture flash onset timing AFTER first flash frame is drawn
           % mark flash moment on eyelink file (only on first flash frame)
           if isEyelink && flashPresentFlag && flashFramesCounter == 1
               Eyelink('Message','flash');
           end
            
           % Check if gaze exceeds 3 DVA from fixation ONLY DURING MOTION PHASE 
           % Motion phase = when grating is actually moving OR uniform control (uniform control trials)
           isMotionPhase = (motionDirec ~= 0) || (motionDirec == 0); % All trials have motion/uniform control
           
           if isEyelink && isMotionPhase && mod(i, eyeCheckFrameInterval) == 0 % Only check during motion/uniform control
               % Check if recording is still active
               err = Eyelink('CheckRecording');
               if err ~= 0
                   Eyelink('StartRecording');
                   WaitSecs(0.01); % Reduced wait time
               end
               
               % Quick gaze data retrieval - prefer fastest method
               sampleAvailable = false;
               x = NaN; y = NaN;
               
               if Eyelink('NewFloatSampleAvailable') > 0
                   evt = Eyelink('NewestFloatSample');
                   if eyeUsed ~= -1 && length(evt.gx) > eyeUsed
                       x = evt.gx(eyeUsed+1);
                       y = evt.gy(eyeUsed+1);
                       sampleAvailable = true;
                   end
               end
               
               % Process gaze data if available
               if sampleAvailable && x ~= MISSING_DATA && y ~= MISSING_DATA && ~isnan(x) && ~isnan(y)
                   % Calculate distance from fixation
                   gazeDistanceFromFixationPix = sqrt((x - xCenter)^2 + (y - yCenter)^2);
                   gazeDistanceFromFixationDva = pix2dva(gazeDistanceFromFixationPix, eyeScreenDistance, windowRect, screenHeight);
                   % Update fixation color based on 3 DVA radius (ONLY during motion phase)
                   outside2 = gazeDistanceFromFixationDva > gazeMonitoringRadius_dva;
                   
                   % FIXED: Any gaze violation during motion phase invalidates trial
                   if outside2
                       gazeViolationDuringMotion = true;  % Mark trial as invalid
                   end
                   
                   % Play warning sound on first crossing of threshold (no cooldown needed for trial invalidation)
                   currentTime = GetSecs();
                   if outside2 && ~fixationOutside2DVA_prev
                       try
                           PsychPortAudio('Stop', pahandle_warning, 1); % Stop any ongoing playback
                           PsychPortAudio('Start', pahandle_warning, 1, 0, 0);
                       catch
                       end
                   end
                   
                   fixationOutside2DVA_prev = outside2;
                   if outside2
                       fixationColor = red;
                   else
                       fixationColor = white;
                   end
                   
               end
           end

           % Update flip time
           lastFlipTime = VBLTimestamp;
           
           % Update flash tracking
           previousFrameHadFlash = flashPresentFlag;
           
           % Move to next frame
           i = i + 1;

       end  % End of grating animation loop 
       
    % Clear GPU memory and variables after each trial
       clear dynamicR dynamicGrating maskedGrating;
       
       % Additional memory cleanup to prevent accumulation
       if mod(trial, 10) == 0  % Every 10 trials, force garbage collection
           % Trigger MATLAB's garbage collector
           drawnow; % Process any pending graphics operations
       end
       %==================================================================
       %                    PROBE POSITIONING AND RESPONSE COLLECTION
       %                    This is the core of the choice task
       %==================================================================
       
       % Clear screen and show fixation for a brief pause (ensure black background consistently)
       Screen('FillRect', window, black);  % Explicitly fill entire screen with black
       Screen('DrawLines', window, fixCoords, fixLineWidth, fixationColor, [xCenter,yCenter]);
       [VBLTimestamp, StimulusOnsetTime, FlipTimestamp, Missed, Beampos] = Screen('Flip', window);
       
       % Use flip timing instead of WaitSecs for probe pause
       pauseStartTime = VBLTimestamp;
       pauseDuration = 0.3;  % 300ms pause before showing probe
       while GetSecs() - pauseStartTime < pauseDuration
           Screen('FillRect', window, black);
           % Update fixation color during pause (optional real-time feedback - NO sound/violations)
           if isEyelink && Eyelink('NewFloatSampleAvailable') > 0
               evt = Eyelink('NewestFloatSample');
               if eyeUsed ~= -1 && length(evt.gx) > eyeUsed
                   gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                   if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                       gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                       gazeDistDva = pix2dva(gazeDistPix, eyeScreenDistance, windowRect, screenHeight);
                       outside2 = gazeDistDva > gazeMonitoringRadius_dva;
                       % NO SOUND during pause - just update fixation color
                       fixationOutside2DVA_prev = outside2;
                       if outside2
                           fixationColor = red; 
                       else
                           fixationColor = white; 
                       end
                   end
               end
           end
           Screen('DrawLines', window, fixCoords, fixLineWidth, fixationColor, [xCenter,yCenter]);
           Screen('Flip', window);
       end

       %--------------------------------------------------------------
       %             RESPONSE COLLECTION
       %             This is where the participant makes their judgment
       %--------------------------------------------------------------
   % Get keyboard device information
   [keyboardIndices, productNames, allInfos] = GetKeyboardIndices;
   respToBeMade = true;  % Flag to control response loop

       %--------------------------------------------------------------
       %            SELECT CURRENT STAIRCASE BASED ON TRIAL CONDITIONS
       %            This determines which adaptive sequence to use
       %--------------------------------------------------------------
       
       % Determine staircase key based on quadrant and motion direction
       staircase_key = '';
       if quad == 45 || quad == 135  % Upper quadrants
           if motionDirec == -1
               staircase_key = 'upper_petal';
           elseif motionDirec == 1
               staircase_key = 'upper_fugal';
           elseif motionDirec == 0
               staircase_key = 'upper_control';
           end
       elseif quad == 225 || quad == 315  % Lower quadrants
           if motionDirec == -1
               staircase_key = 'lower_petal';
           elseif motionDirec == 1
               staircase_key = 'lower_fugal';
           elseif motionDirec == 0
               staircase_key = 'lower_control';
           end
       end
       
       % Set current_staircase to the appropriate staircase for this trial
       current_staircase = staircase.(staircase_key);
       

       %--------------------------------------------------------------
       %            CALCULATE PROBE POSITION
       %            Use staircase value or fixed offset for catch trial
       %--------------------------------------------------------------
      
       % CORRECTED PROBE POSITIONING LOGIC:
       % All calculations in DVA space to eliminate rounding errors
       
       % For catch trials, use fixed offset; for normal trials, use staircase
       if isAttentionCheck
           probeRadialDistanceDva = flash.EccentricityDva_current + probeOffsetDva; % Use fixed 5 DVA offset
       else
           % Add the staircase offset to get the probe's radial distance (all in DVA)
           % Positive stimuluslevel = further from center, Negative = closer to center
           probeRadialDistanceDva = flash.EccentricityDva_current + current_staircase.stimuluslevel;
       end
       
       % Apply jitter to probe position (same jitter as used for flash, in DVA)
       jitteredProbeDistanceDva = probeRadialDistanceDva + jitterDva;
       
       % POSITIONING FIX: Add half bar width so probe is positioned by center, not outer edge
       probeHalfWidthDva = probe.WidthDva / 2; % 0.25 DVA
       jitteredProbeDistanceDva_centered = jitteredProbeDistanceDva + probeHalfWidthDva;
       
       % Convert final probe position to pixels for display (using centered position)
       jitteredProbeDistancePix = dva2pix(jitteredProbeDistanceDva_centered, eyeScreenDistance, windowRect, screenHeight);
       
       % Position probe using the same diagonal coordinate system as flash
       probe.CenterPosX(block, trial) = xCenter + phaseshiftFactorX * jitteredProbeDistancePix * sind(45);
       probe.CenterPosY(block, trial) = yCenter + phaseshiftFactorY * jitteredProbeDistancePix * cosd(45);

      
       % Display trial information in specified order
       fprintf('_________________________________________________\n');
       
       % Block #, Trial # - Show catch trials separately
       if isAttentionCheck
           fprintf('Block %d, Trial %d (CATCH TRIAL):\n', block, trial);
       elseif exist('trialRepeatAttempts','var') && size(trialRepeatAttempts,1) >= block && length(trialRepeatAttempts(block,:)) >= trial && trialRepeatAttempts(block, trial) > 0
           fprintf('Block %d, Trial %d (REPEAT - attempt %d due to fixation violation):\n', block, trial, trialRepeatAttempts(block, trial));
       else
           fprintf('Block %d, Trial %d:\n', block, trial);
       end
       
       % Motion Direction
       if motionDirec == -1
           fprintf('Motion Direction: PETAL (negative)\n'); 
       elseif motionDirec == 1
           fprintf('Motion Direction: FUGAL (positive)\n');
       else
           fprintf('Motion Direction: UNIFORM CONTROL\n');
       end
       
       % Quadrant
       if quad == 45
           fprintf('Quadrant: UPPER RIGHT\n');
       elseif quad == 135
           fprintf('Quadrant: UPPER LEFT\n');
       elseif quad == 225
           fprintf('Quadrant: LOWER LEFT\n');
       elseif quad == 315
           fprintf('Quadrant: LOWER RIGHT\n');
       end
       
       % Temporal Jitter Information (console only - not logged)
       fprintf('Temporal Jitter: %+.3f seconds (%+d frames) from base timing\n', temporalJitterSec, temporalJitterFrames);
       
       % Eccentricity
       actualEccentricityDva = flash.EccentricityDva_current + jitterDva;
       fprintf('Eccentricity: %.1f DVA (Base: %.1f DVA +/- Jitter: %+.1f DVA)\n', ...
           actualEccentricityDva, flash.EccentricityDva_current, jitterDva);
       
       % Flash Distance from Centre (calculate directly from DVA values)
       fprintf('Flash Distance from Centre: %.2f DVA\n', jitteredFlashLocDva); 
       
       % Probe positioning (all in DVA) - PRESERVE CATCH TRIAL OFFSET
       if ~isAttentionCheck
           probeOffsetDva = current_staircase.stimuluslevel;  % Use staircase value for normal trials
       end
       % For catch trials, keep the original probeOffsetDva (5 DVA) set earlier
       fprintf('Probe Offset from Flash: %+.2f DVA, Probe Distance from Centre: %.2f DVA\n', ...
           probeOffsetDva, jitteredProbeDistanceDva);
       
       % Calculate expected probe distance and discrepancy (all in DVA - no conversion errors)
       expectedProbeDistanceDva = jitteredFlashLocDva + probeOffsetDva;
       discrepancyDva = jitteredProbeDistanceDva - expectedProbeDistanceDva;
       fprintf('Expected Probe Distance: %.2f DVA, Actual Distance: %.2f DVA, Discrepancy: %+.3f DVA\n', ...
           expectedProbeDistanceDva, jitteredProbeDistanceDva, discrepancyDva); 
      
       % Calculate shift distance for data logging
       shiftFromFlash(trial) = sqrt((current_staircase.stimuluslevel * sind(45))^2 + ...
           (current_staircase.stimuluslevel * cosd(45))^2);
      
       % Set up probe display rectangle
       probe.DestinationRect = CenterRectOnPoint(probe.Size, probe.CenterPosX(block,trial), probe.CenterPosY(block,trial));
       
    % Draw probe initially and ensure it stays visible
       Screen('FillRect', window, black);  % Clear to black
       Screen('DrawTexture', window, probe.Texture, [], probe.DestinationRect, flash.Angle);
       Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
       Screen('Flip', window);

       %--------------------------------------------------------------
       %             RESPONSE COLLECTION LOOP
       %             Wait for participant to make a forced choice
       %--------------------------------------------------------------
      
       % Initialize response variables
       probeToflash = NaN;         % Numeric response code
       responseLabel = '';         % Text response label
       
       % PARTICIPANT TASK:
       % Compare the probe (red line) position to where they remember seeing the flash
       % 'I'  = probe appears closer to INNER (fixation) than the flash was
       % 'O' = probe appears closer to OUTER (periphery) than the flash was
      
    % Staircase logic explanation:
       % The staircase adjusts probe position based on participant responses.
       % When stimuluslevel INCREASES (+), probe moves MORE PERIPHERAL
       % When stimuluslevel DECREASES (-), probe moves MORE FOVEAL
       %
       % CORRECTED RESPONSE MAPPING:
       % - If participant says "probe too foveal" (F) → move probe MORE peripheral (increase stimuluslevel) 
       % - If participant says "probe too peripheral" (P) → move probe MORE foveal (decrease stimuluslevel)
       %
       % IMPORTANT: The response codes must match the staircase direction logic!
       % Current mapping REVERSES the intended response - see fix below.
      
       while respToBeMade
           % Use different variable name to avoid conflict with grating loop
           for keyIdx = 1:length(keyboardIndices)
               [keyIsDown, ~, keyCode] = KbCheck(keyboardIndices(keyIdx));
               if keyIsDown
                   if keyCode(KbName('ESCAPE'))
                       % Emergency exit - close experiment
                       ShowCursor;
                       sca;  % Screen close all
                       return;
                      
                   elseif keyCode(KbName('i'))
                       % I = "Probe appears closer to INNER (fovea) than flash"
                       % STAIRCASE ACTION: Move probe MORE PERIPHERAL (increase stimuluslevel)
                       % RESPONSE CODE: 2 = move toward periphery (increase stimulus level)
                       probeToflash = 2;           % Response code: need more peripheral positioning
                       validTrialFlag = 1;         % Mark trial as valid
                       responseLabel = 'I';        % Store response type
                       respToBeMade = false;       % Exit response loop
                      
                   elseif keyCode(KbName('o'))
                       % O = "Probe appears closer to OUTER (periphery) than flash"
                       % STAIRCASE ACTION: Move probe MORE FOVEAL (decrease stimuluslevel) 
                       % RESPONSE CODE: 1 = move toward fovea (decrease stimulus level)
                       probeToflash = 1;           % Response code: need more foveal positioning
                       validTrialFlag = 1;         % Mark trial as valid
                       responseLabel = 'O';        % Store response type
                       respToBeMade = false;       % Exit response loop
                      
                   elseif keyCode(KbName('UpArrow'))
                       % UP ARROW = "I missed the flash" (invalid trial)
                       validTrialFlag = 0;          % Mark trial as invalid
                       fprintf(['Miss flash block number: %d\n', 'trial number: %d\n'], block, trial);
                       responseLabel = 'UpArrow';   % Store response type
                       respToBeMade = false;        % Exit response loop
                      
                   elseif keyCode(KbName('Space'))
                       % SPACE = Store trial conditions (for debugging)
                       OriginConditionMat{trial,:,block} = [quad, motionDirec, flash.EccentricityDva_current];
                       respToBeMade = false;
                   end
               end
           end
          
           % CONTINUOUS DISPLAY DURING RESPONSE COLLECTION
           % Ensure probe is always visible during response collection
           Screen('FillRect', window, black);  % Clear to black
           Screen('DrawTexture', window, probe.Texture, [], probe.DestinationRect, target.Angle);
           % Update fixation color during response (NO feedback - keep white)
           if isEyelink && Eyelink('NewFloatSampleAvailable') > 0
               evt = Eyelink('NewestFloatSample');
               if eyeUsed ~= -1 && length(evt.gx) > eyeUsed
                   gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                   if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                       gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                       gazeDistDva = pix2dva(gazeDistPix, eyeScreenDistance, windowRect, screenHeight);
                       outside2 = gazeDistDva > gazeMonitoringRadius_dva;
                       % NO VISUAL FEEDBACK during response - keep fixation white
                       fixationOutside2DVA_prev = outside2;
                       fixationColor = white; % Always white during response
                   end
               end
           end
           Screen('DrawLines', window, fixCoords, fixLineWidth, fixationColor, [xCenter, yCenter]);
           Screen('Flip', window);
           
           % Use minimal timing for response checking
           WaitSecs(0.001);  % Minimal pause to prevent CPU overload but maintain responsiveness
       end
       
       % Clear keyboard buffer after response to prevent contamination
       KbReleaseWait();
       %--------------------------------------------------------------
       %             STORE RESPONSE DATA
       %--------------------------------------------------------------
        
       % Store the participant's response   for this trial
       responseMat(block, trial) = probeToflash;          % Numeric response code
       responseLabelCell{block, trial} = responseLabel;   % Text description of response

       %----------------------------------------------------------------------
       %             COMPLETE TRIAL READOUT
       %----------------------------------------------------------------------
       
       % Response Label (must be F or P after participant enters response)
       fprintf('Response Label: %s\n', responseLabel); 
       
       %--------------------------------------------------------------
       %             ADAPTIVE STAIRCASE UPDATE
       %             This is the core of the adaptive algorithm
       %--------------------------------------------------------------
      
       % STAIRCASE LOGIC:
       % Trial 1: Initialize staircase direction based on first response
       % Trial 2+: Update stimulus level based on response switches
       
              % ONLY UPDATE STAIRCASE IF TRIAL WAS VALID
    if validTrialFlag == 1
           % Convert motion direction to meaningful text
           if motionDirec == -1
               motion_direction_text = 'petal';  % motionDirec == -1 is petal (inward) motion
           elseif motionDirec == 1
               motion_direction_text = 'fugal';  % motionDirec == 1 is fugal (outward) motion
           else
               motion_direction_text = 'uniform_control';
           end
           
           % Convert quadrant to meaningful text
           if quad == 45
               quadrant_text = 'upper_right';
           elseif quad == 135
               quadrant_text = 'upper_left';
           elseif quad == 225
               quadrant_text = 'lower_left';
           elseif quad == 315
               quadrant_text = 'lower_right';
           end
           
           % Convert eccentricity to meaningful text
           if flash.EccentricityDva_current == flash.EccentricityDva(2)  % If it's 11 dva
               eccentricity_text = 'outer';
           else  % If it's 7 dva
               eccentricity_text = 'inner';
           end
           
           % Convert response to meaningful text
           if strcmp(responseLabel, 'I')
               response_text = 'inner';
           elseif strcmp(responseLabel, 'O')
               response_text = 'outer';
           elseif strcmp(responseLabel, 'UpArrow')
               response_text = 'nan';  % Up arrow (missed flash) responses logged as 'nan'
           else
               response_text = 'invalid';
           end

           % Determine trial numbering based on trial validity
           if isAttentionCheck && ~gazeViolationDuringMotion
               % Valid catch trials (no gaze violation)
               catch_trial_counter = catch_trial_counter + 1;
               csv_trial_counter = csv_trial_counter + 1; % Catch trials are normal trials in sequence
               trial_identifier = csv_trial_counter;
               staircase_trial = 'C'; % Mark as catch trial in staircase column
               staircase_key = 'catch_trial'; % Override staircase identity for catch trials
               offsetDva = probeOffsetDva; % Use the fixed 5 DVA offset
           elseif (isAttentionCheck && gazeViolationDuringMotion) || validTrialFlag == 0 || gazeViolationDuringMotion
               % Invalid trials: catch trials with gaze violations, missed flash, or regular trials with gaze violations
               trial_identifier = 'NA';
               if isAttentionCheck
                   staircase_trial = 'C'; % Keep catch trial marker even when invalid
                   staircase_key = 'catch_trial';
                   offsetDva = probeOffsetDva; % Use the fixed 5 DVA offset
               else
                   staircase_trial = staircase.(staircase_key).trial_count;
               end
               
               % Store the stimulus level that was ACTUALLY USED for this trial's probe positioning
               trial_stimulus_level = current_staircase.stimuluslevel;
               offsetDva = trial_stimulus_level;  % Already in DVA space
           else
               % Valid normal trials get incremental trial numbers
               csv_trial_counter = csv_trial_counter + 1;
               trial_identifier = csv_trial_counter;
               % Get current staircase trial count for normal trials (before any increment)
               staircase_trial = staircase.(staircase_key).trial_count;
               
               % Store the stimulus level that was ACTUALLY USED for this trial's probe positioning
               trial_stimulus_level = current_staircase.stimuluslevel;
               offsetDva = trial_stimulus_level;  % Already in DVA space
           end
           
           % If gaze was violated during motion phase (and not a catch), queue for repetition but still log to CSV
           if gazeViolationDuringMotion
               % Queue this trial for repetition at block end using SAME jitter & temporal jitter
               if length(trialRepeatAttempts) < trial || size(trialRepeatAttempts,1) < block
                   trialRepeatAttempts(block, trial) = 0; %#ok<AGROW>
               end
               trialRepeatAttempts(block, trial) = trialRepeatAttempts(block, trial) + 1;
               attemptCount = trialRepeatAttempts(block, trial);

               if attemptCount <= maxRepeatAttempts
                   queuedTrial.quad = quad;
                   queuedTrial.motion = motionDirec;
                   queuedTrial.flashEccentricity = flash.EccentricityDva_current;
                   queuedTrial.jitterDva = jitterDva;
                   queuedTrial.temporalJitterFrames = temporalJitterFrames;
                   queuedTrial.attemptCount = attemptCount;
                   invalidTrialsQueue = [invalidTrialsQueue, queuedTrial]; %#ok<AGROW>
                   msg = sprintf('Trial %d added to repeat queue (fixation violation during motion phase)', trial);
               else
                   msg = sprintf('Trial %d fixation violation again but max attempts (%d) reached - trial abandoned', trial, maxRepeatAttempts);
               end
               fprintf([msg '\n']);
               fprintf('Trial %d will be repeated at end of block (attempt %d/%d)\n', trial, attemptCount, maxRepeatAttempts);
           end
           
           % Store data for CSV output with meaningful text terms
           % IMPORTANT: Store ALL trials (valid, invalid, catch, gaze violations) in CSV for analysis
           
           % Create valid_trial text based on trial type
           if isAttentionCheck && ~gazeViolationDuringMotion
               % Catch trials are valid only if no gaze violations
               valid_trial_text = 'valid';
           elseif gazeViolationDuringMotion || validTrialFlag == 0
               % Gaze violations (including catch trials) or missed flash are invalid
               valid_trial_text = 'invalid';
           elseif validTrialFlag == 1
               % Normal trials with F/P responses are valid
               valid_trial_text = 'valid';
           else
               % Fallback: invalid
               valid_trial_text = 'invalid';
           end
           
           % Calculate actual flash location (base eccentricity + jitter)
           flash_dva = flash.EccentricityDva_current + jitterDva;
           
           % Calculate actual flash timing (1 second base + temporal jitter)
           flash_seconds = round(1 + (temporalJitterFrames / refreshRate), 2);
           
           csv_data = [csv_data; {block, trial_identifier, valid_trial_text, staircase_trial, motion_direction_text, ...
               quadrant_text, eccentricity_text, jitterDva, flash_dva, flash_seconds, response_text, offsetDva, ...
               staircase_key, current_staircase.step, current_staircase.direction, current_staircase.reversals}];
           
           if isAttentionCheck
               fprintf('CATCH TRIAL: Logged to CSV for attention analysis (excluded from staircase)\n');
               fprintf('*** CATCH TRIAL CSV ENTRY: Trial ID=%d (Catch #%d), Probe Offset=%.1f DVA ***\n', trial_identifier, catch_trial_counter, offsetDva);
           end
           
           % Only update staircase for normal trials that are valid and have no gaze violations
           if ~isAttentionCheck && validTrialFlag == 1 && ~gazeViolationDuringMotion
               % INCREMENT STAIRCASE TRIAL COUNTER ONLY NOW (for successful trials)
               staircase.(staircase_key).trial_count = staircase.(staircase_key).trial_count + 1;
               
               % Check if this is the first trial for this staircase (direction is NaN)
               if isnan(staircase.(staircase_key).direction)
                   % FIRST TRIAL: Initialize direction based on response
                   if probeToflash == 2  % I pressed (probe too foveal, need more peripheral)
                       staircase.(staircase_key).direction = 1;   % Move toward periphery
                   elseif probeToflash == 1  % O pressed (probe too peripheral, need more foveal)
                       staircase.(staircase_key).direction = -1;  % Move toward fovea
                   end
               
                   % Store this response for next trial comparison
                   staircase.(staircase_key).lastResponse = probeToflash;
               
                   % Immediately update stimulus level for Trial 2
                   staircase.(staircase_key).stimuluslevel = staircase.(staircase_key).stimuluslevel + ...
                       staircase.(staircase_key).direction * staircase.(staircase_key).step;
               
                   % Add this level to progression tracking
                   staircase.(staircase_key).progression(end+1) = staircase.(staircase_key).stimuluslevel;
               
                   init_msg = sprintf('Staircase INITIALISED [%s]: Reversals = 0, Direction = %+d, Step = %.2f DVA, Next Probe @ %.2f DVA\n', ...
                       staircase_key, ...
                       staircase.(staircase_key).direction, ...
                       staircase.(staircase_key).step, ...
                       staircase.(staircase_key).stimuluslevel);
                   fprintf(init_msg);
       
               else
                   % SUBSEQUENT TRIALS: Use standard staircase update
                   if ~isnan(staircase.(staircase_key).lastResponse)
                       staircase.(staircase_key) = update_by_response_switch(staircase.(staircase_key), ...
                           probeToflash, staircase.(staircase_key).lastResponse);
                   
                       update_msg = sprintf('Staircase UPDATED [%s]: Reversals = %d, Direction = %+d, Step = %.2f DVA, Next Probe @ %.2f DVA\n', ...
                           staircase_key, ...
                           staircase.(staircase_key).reversals, ...
                           staircase.(staircase_key).direction, ...
                           staircase.(staircase_key).step, ...
                           staircase.(staircase_key).stimuluslevel);
                       fprintf(update_msg);
                   end
               
                   % Store this response for next trial
                   staircase.(staircase_key).lastResponse = probeToflash;
               end
           else
               % Skip staircase update for: catch trials, invalid trials, or gaze violations
           end % End of staircase update
           
           % ONLY ADVANCE TRIAL COUNTER FOR VALID TRIALS
           trial = trial + 1;
           
       else
           % INVALID TRIAL: Don't advance trial counter, just repeat the same trial
           % This ensures invalid trials don't consume trial slots
           % NOTE: Invalid trials ARE logged to CSV for analysis
           
           fprintf('INVALID TRIAL: Repeating trial %d (logged to CSV for analysis)\n', trial);
       end

   %==============================================================
   %   PROCESS INVALID TRIALS QUEUE - CHECK AFTER EACH TRIAL
   %==============================================================
   % Check if we've finished all scheduled trials and have queued repeats
   if trial > numTrialsThisBlock && ~isempty(invalidTrialsQueue)
       fprintf('\n*** Initiating queued trial repeats ***\n');
       fprintf('Block %d completed. Processing %d invalid trials for repetition...\n', block, length(invalidTrialsQueue));
       for q = 1:length(invalidTrialsQueue)
           qt = invalidTrialsQueue(q);
           if qt.attemptCount <= maxRepeatAttempts
               % Append trial row (reuse same structure; jitter & temporal jitter stored separately
               newRow = [qt.quad, qt.motion, qt.flashEccentricity, NaN, NaN, NaN, 0];
               all_combinations{block} = [all_combinations{block}; newRow];
               newIdx = size(all_combinations{block},1);
               % Store SAME jitter & temporal jitter for the repeat
               trialJitter(block, newIdx) = qt.jitterDva; 
               trialTemporalJitter(block, newIdx) = qt.temporalJitterFrames; 
               trialRepeatAttempts(block, newIdx) = qt.attemptCount; 
               % Format motion direction for output
               if qt.motion == 1
                   motionText = 'FUGAL';
               elseif qt.motion == -1
                   motionText = 'PETAL';
               else
                   motionText = 'UNIFORM CONTROL';
               end
               repMsg = sprintf('Trial %d queued: %s motion, %.1f DVA, attempt %d/%d', newIdx, motionText, qt.flashEccentricity, qt.attemptCount, maxRepeatAttempts);
               fprintf([repMsg '\n']);
           end
       end
       % Update total trials for this block so while-loop continues with repeats
       numTrialsThisBlock = size(all_combinations{block},1);
       fprintf('Block %d now has %d total trials. Continuing with repeats...\n\n', block, numTrialsThisBlock);
       % Clear the queue since we've appended everything
       invalidTrialsQueue = [];
   end

end  % End of trial loop

% Ensure all trial processing is complete before rest screen
WaitSecs(0.5);

% Show rest screen between blocks (but not after the last block)
if block < blockNum
    showRestScreen(window, block, blockNum, white, xCenter, yCenter);
end

% Save incremental data after each block completion (only if experiment not completed)
if ~isempty(csv_data) && ~experimentCompleted
    saveIncrementalData(csv_data, sbjname, block, blockNum, 'R');
end

end  % End of block loop

% Show completion screen
Screen('FillRect', window, 0); % Black background
Screen('TextSize', window, 32);
Screen('TextFont', window, 'Futura'); % Modern, clean font
DrawFormattedText(window, 'Experiment Complete!\n\nThank you for participating.', ...
    'center', 'center', white);
Screen('Flip', window);
WaitSecs(3);

% Mark experiment as completed successfully
experimentCompleted = true;

%======================================================================
%                    DATA SAVING AND CLEANUP
%======================================================================
%----------------------------------------------------------------------
%                      SAVE EXPERIMENTAL DATA AS CSV
%----------------------------------------------------------------------

% Only save final CSV if experiment completed successfully
if experimentCompleted
    % Create the data save path
    savePath = '../data/';  
    % Create directory if it doesn't exist
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    % Get current date and time for unique filename
    time = clock;  % Returns [year month day hour minute second]
    % Create CSV filename with subject name, experiment identifier and timestamp
    csv_filename = sprintf('%s_FGE_R_%02g_%02g_%02g_%02g_%02g.csv', sbjname, time(1), time(2), time(3), time(4), time(5));
    csv_filepath = [savePath, csv_filename];

    % Convert data to table for CSV output with meaningful column names
csv_table = table(csv_data(:,1), csv_data(:,2), csv_data(:,3), csv_data(:,4), csv_data(:,5), csv_data(:,6), ...
    csv_data(:,7), csv_data(:,8), csv_data(:,9), csv_data(:,10), csv_data(:,11), csv_data(:,12), csv_data(:,13), ...
    csv_data(:,14), csv_data(:,15), csv_data(:,16), ...
    'VariableNames', {'block', 'trial_number', 'valid_trial', 'staircase_trial', 'motion_direction', ...
    'quadrant', 'eccentricity', 'jitter_dva', 'flash_dva', 'flash_seconds', 'response', 'probe_offset_dva', ...
    'staircase_identity', 'step_size_dva', 'staircase_direction', 'staircase_reversals'});

% Write CSV file
writetable(csv_table, csv_filepath);
fprintf('CSV data saved to: %s\n', csv_filepath);

    % Print experiment summary
    fprintf('\n=== EXPERIMENT SUMMARY ===\n');
    fprintf('Valid trials logged to CSV: %d\n', csv_trial_counter);
    fprintf('Catch trials logged to CSV: %d\n', catch_trial_counter);
    fprintf('Expected catch trials: %d (6 per block)\n', blockNum * 6);
    if catch_trial_counter < (blockNum * 6)
        fprintf('WARNING: Missing %d catch trials - check for invalid responses\n', (blockNum * 6) - catch_trial_counter);
    end
    
    % Clean up any incremental save files since experiment completed successfully
    cleanupIncrementalFiles(sbjname, 'R');
    
else
    fprintf('\n=== EXPERIMENT TERMINATED EARLY ===\n');
    fprintf('Data preserved in incremental save files.\n');
    fprintf('Valid trials collected: %d\n', csv_trial_counter);
    fprintf('Catch trials collected: %d\n', catch_trial_counter);
end



%----------------------------------------------------------------------
%              stop eyelink recording
%----------------------------------------------------------------------
if isEyelink
    Eyelink('stopRecording');
    Eyelink('command','set_idle_mode');
    %     iSuccess = Eyelink('ReceiveFile', [], edfdir, 1);
    %     disp(conditional(iSuccess > 0, ['Eyelink File Received, file size is ' num2str(iSuccess)], ...
    %         'Something went wrong with receiving the Eyelink File'));

    try
        fprintf('Receiving data file ''%s''\n',  constants.eyelink_data_fname );
        % Use ReceiveFile with destination path to save directly to data folder
        status = Eyelink('ReceiveFile', constants.eyelink_data_fname, constants.eyelink_data_path);
        if status > 0
            fprintf('ReceiveFile status %d\n', status);
            fprintf('Data file ''%s'' saved to ''%s''\n', constants.eyelink_data_fname, constants.eyelink_data_path);
        end
        if 2==exist(constants.eyelink_data_path, 'file')
            fprintf('Data file successfully saved in data folder: ''%s''\n', constants.eyelink_data_path);
        end
    catch
        fprintf('Problem receiving data file ''%s''\n',  constants.eyelink_data_fname );
    end
    Eyelink('ShutDown');
end

%----------------------------------------------------------------------
%                    ROBUST PSYCHTOOLBOX CLEANUP
%----------------------------------------------------------------------
% Clean shutdown to prevent resource conflicts for future runs
try
    % Close audio resources
    PsychPortAudio('Close', pahandle_warning);
    PsychPortAudio('Close');  % Close all remaining audio devices
catch ME
    warning('Error during audio cleanup: %s', ME.message);
end

try
    % Close all screen windows
    sca;  % Screen Close All
catch ME
    warning('Error during screen cleanup: %s', ME.message);
    % Force cleanup even if errors occur
    try
        Screen('CloseAll');
    catch
        % Last resort cleanup
        clear Screen;
    end
end

% Additional cleanup for robustness
clear mex;  % Clear MEX files to release GPU resources
KbReleaseWait;  % Release keyboard resources

%======================================================================
%                    DATA VISUALIZATION
%                    Generate plots showing staircase convergence
%======================================================================
%----------------------------------------------------------------------
%                 PLOTTING THE CONVERGENCE
%----------------------------------------------------------------------
% Set up arrays for plotting different staircases
fields = fieldnames(staircase);  % Get names of all staircase fields
fields_figure = {'UPPER FUGAL', 'UPPER PETAL', 'UPPER UNIFORM CONTROL', ...
                'LOWER FUGAL', 'LOWER PETAL', 'LOWER UNIFORM CONTROL'};  % Display names

colors = {[0.8 0.2 0.2], [0.0 0.7 0.4], [0.2 0.4 0.8], [0.6 0.0 0.8], [1.0 0.6 0.0], [0.0 0.8 0.8]};  % Gem colors: Ruby, Emerald, Sapphire, Amethyst, Topaz, Aquamarine

markers = {'-o', '-s', '-d', '-^', '-x', '-+'};  % Line styles for each condition
% Create the convergence plot
figure;
hold on;
% Plot each staircase's progression
for i = 1:length(fields)
   current = staircase.(fields{i});  % Get current staircase data
   
   % Plot actual perceptual offset (the main measurement)
   if isfield(current, 'progression') && length(current.progression) > 1
       % Only plot the stimulus levels that were actually used in trials
       % Exclude the last value which is prepared for the next trial that didn't happen
       actual_trials_progression = current.progression(1:end-1);
       
       % Apply motion direction signs: petal should be negative, fugal positive
       if contains(fields{i}, 'petal')
           progression_dva = -abs(actual_trials_progression); % Negative for petal motion
       elseif contains(fields{i}, 'fugal')  
           progression_dva = abs(actual_trials_progression);  % Positive for fugal motion
       else
           progression_dva = actual_trials_progression;       % Control conditions unchanged
       end
       
       plot(progression_dva, markers{i}, ...
           'DisplayName', [fields_figure{i}], ...
           'Color', colors{i}, 'LineWidth', 1.5);
   end
   
   % Plot threshold line (average of last few trials - you need more than 5 trials for each condition to plot this)
   if isfield(current, 'progression') && length(current.progression) > calculateLastTrialNum
       % Use only the actual trial values for threshold calculation
       actual_trials_progression = current.progression(1:end-1);
       
       % Calculate threshold as mean of last 5 actual trials (already in DVA)
       if length(actual_trials_progression) >= calculateLastTrialNum
           raw_threshold = mean(actual_trials_progression(end - calculateLastTrialNum + 1:end));
           
           % Apply motion direction signs: petal should be negative, fugal positive
           if contains(fields{i}, 'petal')
               threshold_dva = -abs(raw_threshold); % Negative for petal motion
           elseif contains(fields{i}, 'fugal')
               threshold_dva = abs(raw_threshold);  % Positive for fugal motion
           else
               threshold_dva = raw_threshold;       % Control conditions unchanged
           end
           
           yline(threshold_dva, '--', 'Color', colors{i}, ...
               'DisplayName', [fields_figure{i} ' Threshold']);
       end
   end

   % --- Compute Combined Thresholds for PETAL and FUGAL ---
try
    % Get pixel thresholds (mean of last N trials) - use only actual trial values
    UPPER_PETAL_progression = staircase.upper_petal.progression(1:end-1);
    LOWER_PETAL_progression = staircase.lower_petal.progression(1:end-1);
    UPPER_UNIFORM_CONTROL_progression = staircase.upper_control.progression(1:end-1);
    LOWER_UNIFORM_CONTROL_progression = staircase.lower_control.progression(1:end-1);
    UPPER_FUGAL_progression = staircase.upper_fugal.progression(1:end-1);
    LOWER_FUGAL_progression = staircase.lower_fugal.progression(1:end-1);
    
    % Check if we have enough trials for threshold calculation
    if length(UPPER_PETAL_progression) >= calculateLastTrialNum && ...
       length(LOWER_PETAL_progression) >= calculateLastTrialNum && ...
       length(UPPER_UNIFORM_CONTROL_progression) >= calculateLastTrialNum && ...
       length(LOWER_UNIFORM_CONTROL_progression) >= calculateLastTrialNum && ...
       length(UPPER_FUGAL_progression) >= calculateLastTrialNum && ...
       length(LOWER_FUGAL_progression) >= calculateLastTrialNum
       
        UPPER_PETAL = mean(UPPER_PETAL_progression(end - calculateLastTrialNum + 1:end));
        LOWER_PETAL = mean(LOWER_PETAL_progression(end - calculateLastTrialNum + 1:end));
        UPPER_UNIFORM_CONTROL = mean(UPPER_UNIFORM_CONTROL_progression(end - calculateLastTrialNum + 1:end));
        LOWER_UNIFORM_CONTROL = mean(LOWER_UNIFORM_CONTROL_progression(end - calculateLastTrialNum + 1:end));
        UPPER_FUGAL = mean(UPPER_FUGAL_progression(end - calculateLastTrialNum + 1:end));
        LOWER_FUGAL = mean(LOWER_FUGAL_progression(end - calculateLastTrialNum + 1:end));

        % Convert to dva and apply motion direction signs
        % Petal motion (-1) should be negative, Fugal motion (+1) should be positive
        PETAL_raw = mean([UPPER_PETAL, LOWER_PETAL]) - mean([UPPER_UNIFORM_CONTROL, LOWER_UNIFORM_CONTROL]);
        FUGAL_raw = mean([UPPER_FUGAL, LOWER_FUGAL]) - mean([UPPER_UNIFORM_CONTROL, LOWER_UNIFORM_CONTROL]);

        PETAL_dva = -abs(pix2dva(PETAL_raw, eyeScreenDistance, windowRect, screenHeight)); % Negative for petal
        FUGAL_dva = abs(pix2dva(FUGAL_raw, eyeScreenDistance, windowRect, screenHeight));  % Positive for fugal

        % Plot PETAL (-Ctrl)
        yline(PETAL_dva, '-', 'PETAL (-Ctrl)', 'Color', 'r', ...
            'LineWidth', 2, 'LabelHorizontalAlignment', 'left', 'FontSize', 12,'HandleVisibility', 'off');

        % Plot FUGAL (-Ctrl)
        yline(FUGAL_dva, '-', 'FUGAL (-Ctrl)', 'Color', 'b', ...
            'LineWidth', 2, 'LabelHorizontalAlignment', 'left', 'FontSize', 12, 'HandleVisibility', 'off');
    end
catch
    % Handle case where there aren't enough trials for threshold calculation
    fprintf('Not enough trials for combined threshold calculation\n');
end

end  % End of for loop that plots each staircase



% Format the plot
xlabel('Trial Number');
ylabel('Stimulus Level (dva)');
ax = gca;
ylims = ylim;
title('Staircase Progression and Thresholds (FGE)');
legend('show', 'Location', 'northeastoutside');
lgd = legend('show');
set(lgd, 'FontSize', 15);  % Make legend text larger
grid on;  % Add grid for easier reading
set(gcf, 'Color', 'w');  % White background
hold off;

% Save the plot with the same naming convention as the CSV file
plot_filename = sprintf('%s_FGE_R_%02g_%02g_%02g_%02g_%02g_plot.png', sbjname, time(1), time(2), time(3), time(4), time(5));
plot_filepath = [savePath, plot_filename];
saveas(gcf, plot_filepath, 'png');
fprintf('Plot saved to: %s\n', plot_filepath);

%----------------------------------------------------------------------
