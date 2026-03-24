% ======================================================================================
%%                      FLASH-LAG EFFECT TRAINING PROGRAM
%                              Experiment 2 (E2)
%                      Last modified: January 30, 2026 
% ========================================================================================= 
%
%%                                DESCRIPTION:
%      Training program to prepare participants for the main experiment.
%      
%      PHASE 1: FIXATION TRAINING
%         Part A: Maintain fixation for 10 seconds (with violation feedback)
%         Part B: Maintain fixation with peripheral distractors (resets on violation)
%
%      PHASE 2: TASK TRAINING
%         Practice each of the 4 experimental conditions
%
%      NO DATA IS RECORDED - this is purely for familiarisation.
%
%==========================================================================================

clear all; close all;
%----------------------------------------------------------------------
%%                     SETTINGS
%----------------------------------------------------------------------

isEyelink = 1;  % Set to 1 to enable eye tracking

%---------------------------------------------------------------------
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
softBlue = [100 150 255];  % Blue gaze indicator dot
gazeDotSize = 12;  % Size of gaze indicator dot in pixels                        

% MUTE macOS ALERT SOUNDS during training (eliminates all dings)
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

Screen('Resolution', screenNumber, 800, 600); 
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Suppress keyboard input to MATLAB command window
ListenChar(-1);

% Hide cursor - use screen number for macOS compatibility
HideCursor(screenNumber);

Priority(MaxPriority(window));
Screen('BlendFunction', window, 'GL_ONE', 'GL_ZERO');

commandwindow;

eyeScreenDistance = 57;    
screenHeight = 29.4;       
xCenter = windowRect(3) / 2;  
yCenter = windowRect(4) / 2;  
refreshRate = 85;  

quadrants = [45 135 225 315];  

% Navigation help text
navHelpText = '[N] Next    [P] Previous    [Any Key] Continue    [ESC] Quit';

%% FIXATION CROSS
fixCrossDimDva = 0.5;
fixCrossDimPix = dva2pix(fixCrossDimDva, eyeScreenDistance, windowRect, screenHeight);
fixCoords = [-fixCrossDimPix fixCrossDimPix 0 0; 0 0 -fixCrossDimPix fixCrossDimPix];
fixLineWidth = 3;
fixDuration = 0.5;

%% GAZE MONITORING
gazeMonitoringRadius_dva = 3;  
pixPerDva = dva2pix(1, eyeScreenDistance, windowRect, screenHeight);
gazeThresholdPix = gazeMonitoringRadius_dva * pixPerDva;

%% CENTRAL CUE
centralCueType = 2;
centralCueSizeDva = 0.5;  % Match main experiment

%% MOVING BAR (White)
bar.WidthDva = 0.5;   
bar.LengthDva = 3;    
bar.WidthPix = dva2pix(bar.WidthDva, eyeScreenDistance, windowRect, screenHeight);
bar.LengthPix = dva2pix(bar.LengthDva, eyeScreenDistance, windowRect, screenHeight);
bar.HalfWidth = bar.WidthPix / 2;
bar.HalfLength = bar.LengthPix / 2;  

bar.Image = ones(bar.LengthPix, bar.WidthPix, 3) * white;
bar.Texture = Screen('MakeTexture', window, bar.Image);

bar.speedDvaPerSec = 20;
bar.speedPixPerSec = dva2pix(bar.speedDvaPerSec, eyeScreenDistance, windowRect, screenHeight);
bar.speedPixPerFrame = bar.speedPixPerSec / refreshRate;
bar.startDistDva = 3;
bar.endDistDva = 15;
bar.startDistPix = dva2pix(bar.startDistDva, eyeScreenDistance, windowRect, screenHeight);
bar.endDistPix = dva2pix(bar.endDistDva, eyeScreenDistance, windowRect, screenHeight);
bar.movDistPix = bar.endDistPix - bar.startDistPix;

%% FLASH (Red square)
flash.SizeDva = 0.5;
flash.SizePix = dva2pix(flash.SizeDva, eyeScreenDistance, windowRect, screenHeight);
flash.Rect = [0, 0, flash.SizePix, flash.SizePix];
flash.GapFromBarDva = 0.5;
flash.GapFromBarPix = dva2pix(flash.GapFromBarDva, eyeScreenDistance, windowRect, screenHeight);
flash.presentFrame = 4;

flash.TotalOffsetPix = (bar.LengthPix/2) + flash.GapFromBarPix + (flash.SizePix/2);

flash.Image = zeros(flash.SizePix, flash.SizePix, 3);
flash.Image(:,:,1) = white;
flash.Texture = Screen('MakeTexture', window, flash.Image);

flash.EccentricityDva = [7, 11];  
flash.JitterDva = [-1, 0, 1];

sin45 = sind(45);
cos45 = cosd(45);

flash.EccentricityPix = flash.EccentricityDva * pixPerDva;
flash.JitterPix = flash.JitterDva * pixPerDva;

%% CENTRAL CUE TEXTURE
if centralCueType == 2
    centralCueSizePix = centralCueSizeDva * pixPerDva;
    centralCueRect = [0, 0, centralCueSizePix, centralCueSizePix];
    centralCueImage = zeros(round(centralCueSizePix), round(centralCueSizePix), 3);
    centralCueImage(:,:,1) = white;
    centralCueTexture = Screen('MakeTexture', window, centralCueImage);
    centralCueDestRect = CenterRectOnPoint(centralCueRect, xCenter, yCenter);
end

%% PROBE
probe.SizePix = dva2pix(0.5, eyeScreenDistance, windowRect, screenHeight);
probe.Rect = [0, 0, probe.SizePix, probe.SizePix];

probe.Image = ones(probe.SizePix, probe.SizePix, 3) * grey;
probe.Texture = Screen('MakeTexture', window, probe.Image);

probe.BarWidthPix = dva2pix(0.5, eyeScreenDistance, windowRect, screenHeight);
probe.BarLengthPix = dva2pix(3, eyeScreenDistance, windowRect, screenHeight);
probe.BarRect = [0, 0, probe.BarWidthPix, probe.BarLengthPix];
probe.BarImage = ones(probe.BarLengthPix, probe.BarWidthPix, 3) * grey;
probe.BarTexture = Screen('MakeTexture', window, probe.BarImage);

probe.intervalTime = 0.5;
probe.intervalFrames = round(probe.intervalTime * refreshRate);  % Convert to frames

% Mouse-based probe start positions
probe.PeripheralStartDva = 15;  % Peripheral start at 15 DVA on diagonal
probe.PeripheralStartPix = dva2pix(probe.PeripheralStartDva, eyeScreenDistance, windowRect, screenHeight);

Screen('PreloadTextures', window);

%----------------------------------------------------------------------
%%                       SOUND SETUP
%----------------------------------------------------------------------
InitializePsychSound(1);
sampRate = 44100;
soundsFolder = fullfile(fileparts(mfilename('fullpath')), 'Sounds');

% Load quack sound for PHASE 1 (eye gaze training violations)
quackFile = fullfile(soundsFolder, 'quack_5.mp3');
[quackSound, quackFs] = audioread(quackFile);
quackSound = quackSound';  % Transpose to row format for PsychPortAudio
if size(quackSound, 1) == 1
    quackSound = [quackSound; quackSound];  % Make stereo if mono
end
pahandle_quack = PsychPortAudio('Open', [], [], 0, quackFs, 2);
PsychPortAudio('FillBuffer', pahandle_quack, quackSound);

% Load error-notification sound for PHASE 2 (practice trial violations)
errorFile = fullfile(soundsFolder, 'error-notification.mp3');
[errorSound, errorFs] = audioread(errorFile);
errorSound = errorSound';  % Transpose to row format for PsychPortAudio
if size(errorSound, 1) == 1
    errorSound = [errorSound; errorSound];  % Make stereo if mono
end
pahandle_error = PsychPortAudio('Open', [], [], 0, errorFs, 2);
PsychPortAudio('FillBuffer', pahandle_error, errorSound);

% Load success sounds for Phase 1B completion
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

% Open a separate audio handle for Eyelink calibration sounds
pahandle_eyelink = PsychPortAudio('Open', [], [], 0, sampRate, 2);

%----------------------------------------------------------------------
%%                   EYELINK SETUP
%----------------------------------------------------------------------

el = [];
eyeUsed = -1;
MISSING_DATA = -32768;

if isEyelink
    if EyelinkInit(0) ~= 1
        fprintf('EyeLink not available - running without eye tracking\n');
        isEyelink = 0;
    else
        el = EyelinkInitDefaults(window);
        el.calibrationtargetcolour = [255 255 255];
        el.calibrationtargetsize = 1.0;
        el.calibrationtargetwidth = 0.5;
        % Enable calibration beeps and provide audio handle
        el.targetbeep = 1;
        el.feedbackbeep = 1;
        el.ppa_pahandle = pahandle_eyelink;  % Use our audio handle
        Eyelink('command', 'calibration_area_proportion = 0.5 0.5');
        Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, windowRect(3)-1, windowRect(4)-1);
        Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
        EyelinkUpdateDefaults(el);
        EyelinkDoTrackerSetup(el);
        Eyelink('Command', 'set_idle_mode');
        Eyelink('StartRecording');
        eyeUsed = Eyelink('EyeAvailable');
        if eyeUsed == 2
            eyeUsed = 1;
        end
    end
end

%----------------------------------------------------------------------
%%                   CONDITION INSTRUCTIONS
%----------------------------------------------------------------------

conditionNames = {'Flash Baseline', 'Central Cue', 'Flash + Motion', 'Motion + Flash'};

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

%======================================================================
%%                        WELCOME SCREEN
%======================================================================

Screen('FillRect', window, black);
Screen('TextSize', window, 28);
Screen('TextFont', window, 'Futura');

welcomeText = ['TRAINING SESSION\n\n' ...
    'This training will prepare you for the main experiment.\n\n' ...
    'Part 1: Fixation Training\n' ...
    '   Learn to maintain steady central fixation.\n\n' ...
    'Part 2: Task Familiarisation\n' ...
    '   Practice each of the four experimental conditions.\n\n\n' ...
    'Press any key to begin.'];

DrawFormattedText(window, welcomeText, 'center', 'center', white);
Screen('TextSize', window, 16);
DrawFormattedText(window, navHelpText, 'center', windowRect(4) - 40, grey);
Screen('Flip', window);

KbReleaseWait();
waiting = true;
while waiting
    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if keyCode(KbName('ESCAPE'))
            cleanup(isEyelink);
            return;
        else
            waiting = false;
        end
    end
end
KbReleaseWait();

%======================================================================
%%                   PHASE 1A: SIMPLE FIXATION (with violation counting)
%======================================================================

Screen('FillRect', window, black);
Screen('TextSize', window, 28);

phase1aText = ['PART 1A: FIXATION TRAINING\n\n' ...
    'Maintaining central fixation is essential for this experiment.\n\n' ...
    'A white cross will appear in the centre of the screen.\n' ...
    'Keep your gaze fixed on the cross for 5 seconds.\n\n' ...
    'If your gaze deviates beyond the acceptable range,\n' ...
    'a warning tone will sound.\n\n' ...
    'Press any key to begin, or N to skip to Part 1B.'];

DrawFormattedText(window, phase1aText, 'center', 'center', white);
Screen('TextSize', window, 16);
DrawFormattedText(window, navHelpText, 'center', windowRect(4) - 40, grey);
Screen('Flip', window);

KbReleaseWait();
waiting = true;
skipTo1B = false;
while waiting
    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if keyCode(KbName('ESCAPE'))
            cleanup(isEyelink);
            return;
        elseif keyCode(KbName('n'))
            skipTo1B = true;
            waiting = false;
        else
            waiting = false;
        end
    end
end
KbReleaseWait();

% Run fixation with violation counting - up to 2 mandatory attempts
fixPracticeDuration = 5;
attemptNumber = 1;
maxMandatoryAttempts = 2;
proceedToNext = false;

while ~proceedToNext
    %------------------------------------------------------------------
    %   PART 1A: 5-4-3-2-1 COUNTDOWN BEHIND FIXATION (1 sec per number)
    %   Plays sound on gaze violations, resets to 5 on violation
    %------------------------------------------------------------------
    KbReleaseWait();
    
    countdownNumbers = {'5', '4', '3', '2', '1'};
    countdownDuration = 1.0;  % 1 second per number = 5 seconds total
    gazeWasViolated = false;  % Edge detection for sound
    violationCount = 0;
    
    countIdx = 1;
    while countIdx <= 5
        % Play tick sound at start of each countdown number
        try PsychPortAudio('Stop', pahandle_tick, 0); PsychPortAudio('Start', pahandle_tick, 1, 0, 0); catch, end
        
        countdownStartTime = GetSecs();
        countdownViolated = false;
        
        while (GetSecs() - countdownStartTime) < countdownDuration
            % Check for escape or skip
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown
                if keyCode(KbName('ESCAPE'))
                    cleanup(isEyelink);
                    return;
                elseif keyCode(KbName('n'))
                    skipTo1B = true;
                    proceedToNext = true;
                    break;
                end
            end
            if skipTo1B, break; end
            
            % Check gaze
            gazeOK = true;  % Default OK if no eye tracking
            if isEyelink
                evt = Eyelink('NewestFloatSample');
                if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                    gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                    if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                        gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                        gazeOK = gazeDistPix <= gazeThresholdPix;
                    else
                        gazeOK = false;
                    end
                else
                    gazeOK = false;
                end
            end
            
            % Play warning sound on gaze violation (edge detection)
            if ~gazeOK && ~gazeWasViolated
                try PsychPortAudio('Stop', pahandle_warning, 1); PsychPortAudio('Start', pahandle_warning, 1, 0, 0); catch, end
                gazeWasViolated = true;
                violationCount = violationCount + 1;
                countdownViolated = true;
            elseif gazeOK
                gazeWasViolated = false;
            end
            
            % Draw big countdown number behind fixation
            Screen('FillRect', window, black);
            Screen('TextSize', window, 72);
            
            % Calculate fade: starts bright, fades during each number
            elapsedRatio = (GetSecs() - countdownStartTime) / countdownDuration;
            elapsedRatio = min(1, max(0, elapsedRatio));
            fadeBrightness = grey * (1.0 - 0.6 * elapsedRatio);
            
            DrawFormattedText(window, countdownNumbers{countIdx}, 'center', 'center', fadeBrightness);
            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
            
            % Draw blue gaze indicator dot at current gaze position
            if isEyelink && exist('gx', 'var') && exist('gy', 'var') && gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                gazeDotRect = [gx - gazeDotSize/2, gy - gazeDotSize/2, gx + gazeDotSize/2, gy + gazeDotSize/2];
                Screen('FillOval', window, softBlue, gazeDotRect);
            end
            
            Screen('Flip', window);
        end
        
        if skipTo1B, break; end
        
        % Reset to 5 if violated, else advance
        if countdownViolated
            countIdx = 1;  % Reset to '5'
        else
            countIdx = countIdx + 1;
        end
    end
    
    if skipTo1B
        break;
    end
    
    % Show results
    Screen('FillRect', window, black);
    Screen('TextSize', window, 28);
    
    blinkReminder = '\n\nNote: Blinking may also trigger a fixation violation.\n\nPress any key to repeat Part 1A,\nor press N to continue to Part 1B.';
    
    if violationCount == 0
        resultText = ['You had no fixation violations during that interval.' blinkReminder];
    elseif violationCount == 1
        resultText = ['You had 1 fixation violation during that interval.' blinkReminder];
    else
        resultText = [sprintf('You had %d fixation violations during that interval.', violationCount) blinkReminder];
    end
    
    DrawFormattedText(window, resultText, 'center', 'center', white);
    Screen('TextSize', window, 16);
    DrawFormattedText(window, navHelpText, 'center', windowRect(4) - 40, grey);
    Screen('Flip', window);
    
    KbReleaseWait();
    waiting = true;
    while waiting
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown
            if keyCode(KbName('ESCAPE'))
                cleanup(isEyelink);
                return;
            elseif keyCode(KbName('n'))
                proceedToNext = true;
                waiting = false;
            else
                proceedToNext = false;
                waiting = false;
            end
        end
    end
    KbReleaseWait();
end

%======================================================================
%%                   PHASE 1B: FIXATION WITH DISTRACTORS
%======================================================================

Screen('FillRect', window, black);
Screen('TextSize', window, 28);

phase1bText = ['PART 1B: FIXATION WITH PERIPHERAL STIMULI\n\n' ...
    'Red squares will flash in your peripheral vision.\n\n' ...
    'Your task is to maintain central fixation while remaining\n' ...
    'aware of these peripheral stimuli. This mirrors the demands\n' ...
    'of the main experiment.\n\n' ...
    'If your gaze deviates, the timer will reset to 5 seconds.\n\n' ...
    'Press any key when ready, or N to skip to condition training.'];

DrawFormattedText(window, phase1bText, 'center', 'center', white);
Screen('TextSize', window, 16);
DrawFormattedText(window, navHelpText, 'center', windowRect(4) - 40, grey);
Screen('Flip', window);

KbReleaseWait();
waiting = true;
skipToPhase2 = false;
while waiting
    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if keyCode(KbName('ESCAPE'))
            cleanup(isEyelink);
            return;
        elseif keyCode(KbName('n'))
            skipToPhase2 = true;
            waiting = false;
        else
            waiting = false;
        end
    end
end
KbReleaseWait();

% Skip Phase 1B if user pressed N
if ~skipToPhase2

%------------------------------------------------------------------
%   PART 1B: 5-4-3-2-1 COUNTDOWN WITH PERIPHERAL DISTRACTORS
%   Plays sound on gaze violations, resets to 5 on violation
%------------------------------------------------------------------
KbReleaseWait();

countdownNumbers = {'5', '4', '3', '2', '1'};
countdownDuration = 1.0;  % 1 second per number = 5 seconds total
gazeWasViolated = false;  % Edge detection for sound
phase1bViolationCount = 0;

% Distractor settings
distractorFlashDuration = 4;  % frames
distractorInterval = 0.8;     % seconds between flashes
lastFlashTime = 0;
currentFlashFrames = 0;
distractorRect = [];
distractorAngle = 0;

countIdx = 1;
while countIdx <= 5
    % Play tick sound at start of each countdown number
    try PsychPortAudio('Stop', pahandle_tick, 0); PsychPortAudio('Start', pahandle_tick, 1, 0, 0); catch, end
    
    countdownStartTime = GetSecs();
    countdownViolated = false;
    
    while (GetSecs() - countdownStartTime) < countdownDuration
        % Check for escape or skip
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown
            if keyCode(KbName('ESCAPE'))
                cleanup(isEyelink);
                return;
            elseif keyCode(KbName('n'))
                skipToPhase2 = true;
                break;
            end
        end
        if skipToPhase2, break; end
        
        % Check gaze
        gazeOK = true;  % Default OK if no eye tracking
        if isEyelink
            evt = Eyelink('NewestFloatSample');
            if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                    gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                    gazeOK = gazeDistPix <= gazeThresholdPix;
                else
                    gazeOK = false;
                end
            else
                gazeOK = false;
            end
        end
        
        % Play warning sound on gaze violation (edge detection)
        if ~gazeOK && ~gazeWasViolated
            try PsychPortAudio('Stop', pahandle_warning, 1); PsychPortAudio('Start', pahandle_warning, 1, 0, 0); catch, end
            gazeWasViolated = true;
            phase1bViolationCount = phase1bViolationCount + 1;
            countdownViolated = true;
        elseif gazeOK
            gazeWasViolated = false;
        end
        
        % Generate new distractor flash
        if (GetSecs() - lastFlashTime) > distractorInterval && currentFlashFrames == 0
            quad = quadrants(randi(4));
            eccPix = flash.EccentricityPix(randi(2));
            
            if quad == 45
                fx = xCenter + eccPix * sin45;
                fy = yCenter - eccPix * cos45;
                distractorAngle = 135;
            elseif quad == 135
                fx = xCenter - eccPix * sin45;
                fy = yCenter - eccPix * cos45;
                distractorAngle = 45;
            elseif quad == 225
                fx = xCenter - eccPix * sin45;
                fy = yCenter + eccPix * cos45;
                distractorAngle = 135;
            else
                fx = xCenter + eccPix * sin45;
                fy = yCenter + eccPix * cos45;
                distractorAngle = 45;
            end
            
            distractorRect = CenterRectOnPoint(flash.Rect, fx, fy);
            currentFlashFrames = distractorFlashDuration;
            lastFlashTime = GetSecs();
        end
        
        % Draw background + distractor + countdown number + fixation
        Screen('FillRect', window, black);
        
        if currentFlashFrames > 0
            Screen('DrawTexture', window, flash.Texture, [], distractorRect, distractorAngle);
            currentFlashFrames = currentFlashFrames - 1;
        end
        
        Screen('TextSize', window, 72);
        
        % Calculate fade: starts bright, fades during each number
        elapsedRatio = (GetSecs() - countdownStartTime) / countdownDuration;
        elapsedRatio = min(1, max(0, elapsedRatio));
        fadeBrightness = grey * (1.0 - 0.6 * elapsedRatio);
        
        DrawFormattedText(window, countdownNumbers{countIdx}, 'center', 'center', fadeBrightness);
        Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
        
        % Draw blue gaze indicator dot at current gaze position
        if isEyelink && exist('gx', 'var') && exist('gy', 'var') && gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
            gazeDotRect = [gx - gazeDotSize/2, gy - gazeDotSize/2, gx + gazeDotSize/2, gy + gazeDotSize/2];
            Screen('FillOval', window, softBlue, gazeDotRect);
        end
        
        Screen('Flip', window);
    end
    
    if skipToPhase2, break; end
    
    % Reset to 5 if violated, else advance
    if countdownViolated
        countIdx = 1;  % Reset to '5'
    else
        countIdx = countIdx + 1;
    end
end

end  % End of if ~skipToPhase2

% Play success sound only if we didn't skip
if ~skipToPhase2
    try
        PsychPortAudio('Volume', pahandle_woohoo, 0.5);  % Reduce volume to 50%
        PsychPortAudio('Start', pahandle_woohoo, 1, 0, 1);
    catch
    end
end

% Fixation training complete
Screen('FillRect', window, black);
Screen('TextSize', window, 28);
DrawFormattedText(window, 'Fixation training complete.\n\nYou will now practise the four experimental conditions.\n\nPress any key to continue.', 'center', 'center', white);
Screen('TextSize', window, 16);
DrawFormattedText(window, navHelpText, 'center', windowRect(4) - 40, grey);
Screen('Flip', window);

KbReleaseWait();
waiting = true;
while waiting
    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if keyCode(KbName('ESCAPE'))
            cleanup(isEyelink);
            return;
        else
            waiting = false;
        end
    end
end
KbReleaseWait();

%======================================================================
%%                   PHASE 2: CONDITION TRAINING
%======================================================================

conditionOrder = [1, 2, 3, 4];
currentConditionIdx = 1;
quitTraining = false;

while ~quitTraining
    
    currentCondition = conditionOrder(currentConditionIdx);
    currentConditionName = conditionNames{currentCondition};
    
    %------------------------------------------------------------------
    %                    CONDITION INSTRUCTION SCREEN
    %------------------------------------------------------------------
    Screen('FillRect', window, black);
    Screen('TextSize', window, 24);
    
    headerText = sprintf('=== CONDITION %d of 4: %s ===\n\n', currentConditionIdx, upper(currentConditionName));
    footerText = '\n\n\nPress any key to practise this condition.';
    
    fullText = [headerText, conditionInstructions{currentCondition}, footerText];
    DrawFormattedText(window, fullText, 'center', 'center', white);
    Screen('TextSize', window, 16);
    DrawFormattedText(window, navHelpText, 'center', windowRect(4) - 40, grey);
    Screen('Flip', window);
    
    KbReleaseWait();
    waiting = true;
    practiceCondition = false;
    while waiting
        [keyIsDown, ~, keyCode] = KbCheck();
        if keyIsDown
            if keyCode(KbName('ESCAPE'))
                quitTraining = true;
                waiting = false;
            elseif keyCode(KbName('n'))
                currentConditionIdx = mod(currentConditionIdx, 4) + 1;
                waiting = false;
            elseif keyCode(KbName('p'))
                currentConditionIdx = mod(currentConditionIdx - 2, 4) + 1;
                waiting = false;
            else
                waiting = false;
                practiceCondition = true;
            end
        end
    end
    KbReleaseWait();
    
    if quitTraining || ~practiceCondition
        continue;  % Go to next iteration (either quit or navigate to different condition)
    end
    
    successfulTrialsInRow = 0;  % Counter for consecutive successful trials
    
    while practiceCondition && ~quitTraining
        %------------------------------------------------------
        %                GENERATE RANDOM TRIAL
        %------------------------------------------------------
        quad = quadrants(randi(4));
        eccIdx = randi(length(flash.EccentricityDva));
        flashSide = (randi(2) * 2 - 3);
        jitterIdx = randi(length(flash.JitterDva));
        
        if currentCondition == 1
            motionDir = 0;
        else
            motionDir = (randi(2) * 2 - 3);
        end
        
        flashEccPix = flash.EccentricityPix(eccIdx) + flash.JitterPix(jitterIdx);
        flashEccDva = flash.EccentricityDva(eccIdx) + flash.JitterDva(jitterIdx);
                    
                    %------------------------------------------------------
                    %                QUADRANT-SPECIFIC SETUP
                    %------------------------------------------------------
                    if quad == 45
                        phaseshiftFactorX = 1;
                        phaseshiftFactorY = -1;
                        barAngle = 135;
                        arrowKeyFlip = 1;
                    elseif quad == 135
                        phaseshiftFactorX = -1;
                        phaseshiftFactorY = -1;
                        barAngle = 45;
                        arrowKeyFlip = -1;
                    elseif quad == 225
                        phaseshiftFactorX = -1;
                        phaseshiftFactorY = 1;
                        barAngle = 135;
                        arrowKeyFlip = -1;
                    else
                        phaseshiftFactorX = 1;
                        phaseshiftFactorY = 1;
                        barAngle = 45;
                        arrowKeyFlip = 1;
                    end
                    
                    %------------------------------------------------------
                    %       GAZE-CHECKED TRIAL START: 3-2-1 COUNTDOWN
                    %------------------------------------------------------
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
                                if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                                    gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                                    if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                                        gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                                        gazeOK = gazeDistPix <= gazeThresholdPix;
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
                            if gazeOK || ~isEyelink
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
                            if keyIsDown && keyCode(KbName('ESCAPE'))
                                quitTraining = true;
                                practiceCondition = false;
                                break;
                            end
                            
                            % Flush any mouse clicks during this phase
                            [~, ~, buttons] = GetMouse(window);
                        end
                        
                        if quitTraining, break; end
                        
                        % After this countdown step: reset to 3 if violated, else advance
                        if countdownViolated
                            countIdx = 1;  % Reset to '3'
                        else
                            countIdx = countIdx + 1;  % Advance to next number
                        end
                    end
                    
                    if quitTraining, break; end
                    
                    %------------------------------------------------------
                    %                SHOW FIXATION
                    %------------------------------------------------------
                    backgroundColor = black;
                    fixationOutside_prev = false;
                    gazeViolation = false;
                    
                    % Ensure cursor stays hidden during trial
                    HideCursor(screenNumber);
                    
                    Screen('FillRect', window, black);
                    Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                    fixationStartTime = Screen('Flip', window);
                    
                    while GetSecs() - fixationStartTime < fixDuration
                        [keyIsDown, ~, keyCode] = KbCheck();
                        if keyIsDown && keyCode(KbName('ESCAPE'))
                            quitTraining = true;
                            practiceCondition = false;
                            break;
                        end
                        
                        % Check gaze - always try to get newest sample (more reliable)
                        if isEyelink
                            evt = Eyelink('NewestFloatSample');
                            eyeDataMissing = true;  % Assume missing until proven otherwise
                            if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                                gx = evt.gx(eyeUsed+1); 
                                gy = evt.gy(eyeUsed+1);
                                if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                                    eyeDataMissing = false;
                                    gazeDistPix = sqrt((gx - xCenter)^2 + (gy - yCenter)^2);
                                    outside = gazeDistPix > gazeThresholdPix;
                                    
                                    if outside && ~fixationOutside_prev
                                        gazeViolation = true;
                                    end
                                    
                                    fixationOutside_prev = outside;
                                end
                            end
                            % Missing eye data = treat as violation (eyes removed from tracker)
                            if eyeDataMissing
                                gazeViolation = true;
                            end
                        end
                        
                        Screen('FillRect', window, backgroundColor);
                        Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                        Screen('Flip', window);
                    end
                    
                    if quitTraining, break; end
                    
                    %------------------------------------------------------
                    %                STIMULUS PRESENTATION
                    %------------------------------------------------------
                    flashFrameCounter = 0;
                    barLocWhenFlashX = NaN;
                    barLocWhenFlashY = NaN;
                    barDistWhenFlash = NaN;
                    flashLocX = NaN;
                    flashLocY = NaN;
                    
                    %------------------------------------------------------
                    % PRE-COMPUTE FLASH ONSET FRAME (same logic for all conditions)
                    % Flash triggers when bar ENTERS the flash zone (physical overlap)
                    % Flash zone runs PARALLEL to bar (perpendicular offset)
                    % Bar enters zone when bar front edge reaches flash back edge
                    %------------------------------------------------------
                    flashDurationFrames = 4;
                    flashHalfSize = flash.SizePix / 2;
                    
                    if motionDir == 1  % Fugal
                        % Bar front edge = barCenter + bar.HalfWidth
                        % Flash zone starts at flashEccPix - flashHalfSize
                        triggerPointPix = flashEccPix - flashHalfSize - bar.HalfWidth;
                        distanceToTrigger = triggerPointPix - bar.startDistPix;
                    else  % Petal
                        % Bar front edge = barCenter - bar.HalfWidth
                        % Flash zone ends at flashEccPix + flashHalfSize
                        triggerPointPix = flashEccPix + flashHalfSize + bar.HalfWidth;
                        distanceToTrigger = bar.endDistPix - triggerPointPix;
                    end
                    flashOnsetFrame = max(1, round(distanceToTrigger / bar.speedPixPerFrame));
                    
                    if currentCondition == 1
                        %--------------------------------------------------
                        % FLASH BASELINE: Flash only, no visible bar
                        %--------------------------------------------------
                        totalFrames = refreshRate * 1;
                        
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
                        flashRectDraw = CenterRectOnPoint(flash.Rect, flashLocX, flashLocY);
                        
                        for frame = 1:totalFrames
                            Screen('FillRect', window, backgroundColor);
                            
                            % Flash ON from flashOnsetFrame for exactly flashDurationFrames (4 frames)
                            isFlashWindow = (frame >= flashOnsetFrame) && (frame < flashOnsetFrame + flashDurationFrames);
                            
                            if isFlashWindow
                                Screen('DrawTexture', window, flash.Texture, [], flashRectDraw, barAngle);
                                flashFrameCounter = flashFrameCounter + 1;
                            end
                            
                            Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                            Screen('DrawingFinished', window);
                            Screen('Flip', window);
                            
                            if isEyelink
                                % Always try to get newest sample (more reliable than NewFloatSampleAvailable)
                                evt = Eyelink('NewestFloatSample');
                                eyeDataMissing = true;  % Assume missing until proven otherwise
                                if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                                    gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                                    if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                                        eyeDataMissing = false;
                                        gazeDistPix = sqrt((gx-xCenter)^2+(gy-yCenter)^2);
                                        if gazeDistPix > gazeThresholdPix && ~fixationOutside_prev
                                            try PsychPortAudio('Stop',pahandle_error,1); PsychPortAudio('Start',pahandle_error,1,0,0); catch, end
                                            fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\\n');
                                            gazeViolation = true; break;
                                        end
                                        fixationOutside_prev = gazeDistPix > gazeThresholdPix;
                                    end
                                end
                                % Missing eye data = treat as violation (eyes removed from tracker)
                                if eyeDataMissing
                                    try PsychPortAudio('Stop',pahandle_error,1); PsychPortAudio('Start',pahandle_error,1,0,0); catch, end
                                    fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\\n');
                                    gazeViolation = true; break;
                                end
                            end
                        end
                        
                    else
                        %--------------------------------------------------
                        % MOTION CONDITIONS (2, 3, 4): Bar moves, flash at pre-computed frame
                        %--------------------------------------------------
                        if motionDir == 1
                            barDist = bar.startDistPix;
                        else
                            barDist = bar.endDistPix;
                        end
                        
                        totalFrames = round(bar.movDistPix / bar.speedPixPerFrame);
                        
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
                        flashRectDraw = CenterRectOnPoint(flash.Rect, flashLocX, flashLocY);
                        
                        trajMultX = phaseshiftFactorX * sin45;
                        trajMultY = phaseshiftFactorY * cos45;
                        
                        for frame = 1:totalFrames
                            Screen('FillRect', window, backgroundColor);
                            
                            % Calculate bar center position for this frame
                            % (position updated at end of loop to ensure first frame shows initial position)
                            barCenterX = xCenter + trajMultX * barDist;
                            barCenterY = yCenter + trajMultY * barDist;
                            
                            barRectDraw = [barCenterX - bar.HalfWidth, barCenterY - bar.HalfLength, ...
                                       barCenterX + bar.HalfWidth, barCenterY + bar.HalfLength];
                            
                            Screen('DrawTexture', window, bar.Texture, [], barRectDraw, barAngle);
                            
                            % Flash/cue ON from flashOnsetFrame for flashDurationFrames
                            isFlashWindow = (frame >= flashOnsetFrame) && (frame < flashOnsetFrame + flashDurationFrames);
                            
                            % Store bar position on first flash frame
                            if frame == flashOnsetFrame
                                barLocWhenFlashX = barCenterX;
                                barLocWhenFlashY = barCenterY;
                                barDistWhenFlash = barDist;
                            end
                            
                            if isFlashWindow
                                if currentCondition == 2
                                    if centralCueType == 1
                                        Screen('DrawLines', window, fixCoords, fixLineWidth, red, [xCenter, yCenter]);
                                    else
                                        Screen('DrawTexture', window, centralCueTexture, [], centralCueDestRect, barAngle);
                                    end
                                else
                                    Screen('DrawTexture', window, flash.Texture, [], flashRectDraw, barAngle);
                                    flashFrameCounter = flashFrameCounter + 1;
                                end
                            end
                            
                            % Draw fixation cross (unless cue is showing in central cue condition)
                            if ~(currentCondition == 2 && isFlashWindow && centralCueType == 1)
                                if ~(currentCondition == 2 && isFlashWindow && centralCueType == 2)
                                    Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                                end
                            end
                            
                            Screen('DrawingFinished', window);
                            Screen('Flip', window);
                            
                            if isEyelink
                                % Always try to get newest sample (more reliable than NewFloatSampleAvailable)
                                evt = Eyelink('NewestFloatSample');
                                eyeDataMissing = true;  % Assume missing until proven otherwise
                                if eyeUsed ~= -1 && isstruct(evt) && isfield(evt, 'gx') && length(evt.gx) > eyeUsed
                                    gx = evt.gx(eyeUsed+1); gy = evt.gy(eyeUsed+1);
                                    if gx ~= MISSING_DATA && gy ~= MISSING_DATA && ~isnan(gx) && ~isnan(gy)
                                        eyeDataMissing = false;
                                        gazeDistPix = sqrt((gx-xCenter)^2+(gy-yCenter)^2);
                                        if gazeDistPix > gazeThresholdPix && ~fixationOutside_prev
                                            try PsychPortAudio('Stop',pahandle_error,1); PsychPortAudio('Start',pahandle_error,1,0,0); catch, end
                                            fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\\n');
                                            gazeViolation = true; break;
                                        end
                                        fixationOutside_prev = gazeDistPix > gazeThresholdPix;
                                    end
                                end
                                % Missing eye data = treat as violation (eyes removed from tracker)
                                if eyeDataMissing
                                    try PsychPortAudio('Stop',pahandle_error,1); PsychPortAudio('Start',pahandle_error,1,0,0); catch, end
                                    fprintf('  [GAZE VIOLATION during stimulus - trial invalidated]\\n');
                                    gazeViolation = true; break;
                                end
                            end
                            
                            % Update bar position for next frame
                            barDist = barDist + motionDir * bar.speedPixPerFrame;
                        end
                    end
                    
                    %------------------------------------------------------
                    %          HANDLE GAZE VIOLATION: Silent invalidation
                    %------------------------------------------------------
                    if gazeViolation
                        successfulTrialsInRow = 0;  % Reset counter on violation
                        WaitSecs(0.3);  % Brief pause before next trial
                        HideCursor(screenNumber);  % Ensure cursor stays hidden
                        continue;
                    end
                    
                    %------------------------------------------------------
                    %                RESPONSE COLLECTION (Mouse-based)
                    %------------------------------------------------------
                    % Brief pause before probe (frame-based)
                    for intervalFrame = 1:probe.intervalFrames
                        Screen('FillRect', window, black);
                        Screen('DrawLines', window, fixCoords, fixLineWidth, white, [xCenter, yCenter]);
                        Screen('Flip', window);
                    end
                    
                    % Target DVA is always flashEccDva (base eccentricity)
                    targetDva = flashEccDva;
                    
                    % Target location depends on condition
                    if currentCondition == 1 || currentCondition == 3
                        targetLocX = flashLocX;
                        targetLocY = flashLocY;
                    else
                        targetLocX = barLocWhenFlashX;
                        targetLocY = barLocWhenFlashY;
                    end
                    
                    % Probe start position - random (50% fixation, 50% peripheral)
                    probeStartsAtFixation = rand() < 0.5;  % 50% chance fixation
                    if probeStartsAtFixation
                        % Start at fixation (center of screen) - probe center at fixation center
                        probeStartX = xCenter;
                        probeStartY = yCenter;
                    else
                        % Start at EXACTLY 16 DVA from fixation center, along diagonal trajectory
                        peripheralStartDva = 16;
                        peripheralStartPix = dva2pix(peripheralStartDva, eyeScreenDistance, windowRect, screenHeight);
                        
                        % Randomly choose one of the 4 diagonal quadrants
                        randomQuadrantIdx = randi(4);
                        peripheralQuadrant = quadrants(randomQuadrantIdx);  % 45, 135, 225, or 315 degrees
                        
                        % Calculate probe center position at 16 DVA along the diagonal
                        probeStartX = xCenter + peripheralStartPix * sind(peripheralQuadrant);
                        probeStartY = yCenter - peripheralStartPix * cosd(peripheralQuadrant);
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
                    
                    % Track mouse stillness for dynamic text color
                    lastMouseX = probeStartX;
                    lastMouseY = probeStartY;
                    mouseStillSince = GetSecs();
                    mouseStillThreshold = 0.3;  % 300ms to turn white
                    hasMovedProbe = false;  % Must move probe before it can turn white
                    
                    while respToBeMade && ~quitTraining
                        % Enforce cursor hidden every frame (macOS requirement)
                        HideCursor(screenNumber);
                        
                        % Absolute mouse position - no delta integration
                        [probeX, probeY, buttons] = GetMouse(window);
                        
                        % Clamp to screen bounds and WARP mouse back if outside
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
                        if any(buttons)
                            % Play subtle tick sound for confirmation
                            try
                                PsychPortAudio('Stop', pahandle_tick);
                                PsychPortAudio('Start', pahandle_tick, 1, 0, 0);
                            catch
                            end
                            respToBeMade = false;
                        end
                        
                        % Check keys (ESC, N, P for navigation)
                        [~, ~, keyCode] = KbCheck();
                        if keyCode(KbName('ESCAPE'))
                            quitTraining = true; practiceCondition = false; respToBeMade = false;
                        elseif keyCode(KbName('n'))
                            currentConditionIdx = mod(currentConditionIdx, 4) + 1;
                            practiceCondition = false; respToBeMade = false;
                        elseif keyCode(KbName('p'))
                            currentConditionIdx = mod(currentConditionIdx - 2, 4) + 1;
                            practiceCondition = false; respToBeMade = false;
                        end
                    end
                    
                    % Wait for mouse button release before continuing
                    [~, ~, buttons] = GetMouse(window);
                    while any(buttons)
                        [~, ~, buttons] = GetMouse(window);
                    end
                    
                    % Screen('ConstrainCursor', window, X); % Disabled - not supported on macOS
                    
                    % Store final probe position
                    probeBaseX = probeX;
                    probeBaseY = probeY;
                    
                    % If we get here without breaking, trial was successful (no gaze violation)
                    if practiceCondition && ~quitTraining && ~gazeViolation
                        successfulTrialsInRow = successfulTrialsInRow + 1;
                        
                        % After 5 successful trials in a row, offer choice
                        if successfulTrialsInRow >= 5
                            Screen('FillRect', window, black);
                            Screen('TextSize', window, 28);
                            
                            if currentConditionIdx < 4
                                choiceText = sprintf('You have completed 5 successful trials in a row.\n\nPress any key to continue practising this condition,\nor press N to move to the next condition.');
                            else
                                choiceText = sprintf('You have completed 5 successful trials in a row.\n\nPress any key to continue practising this condition,\nor press N to finish training.');
                            end
                            
                            DrawFormattedText(window, choiceText, 'center', 'center', white);
                            Screen('TextSize', window, 16);
                            DrawFormattedText(window, navHelpText, 'center', windowRect(4) - 40, grey);
                            Screen('Flip', window);
                            
                            KbReleaseWait();
                            waiting = true;
                            while waiting
                                [keyIsDown, ~, keyCode] = KbCheck();
                                if keyIsDown
                                    if keyCode(KbName('ESCAPE'))
                                        quitTraining = true; practiceCondition = false; waiting = false;
                                    elseif keyCode(KbName('n'))
                                        currentConditionIdx = currentConditionIdx + 1;
                                        if currentConditionIdx > 4
                                            practiceCondition = false;
                                            quitTraining = true;  % Finished all conditions
                                        else
                                            practiceCondition = false;
                                        end
                                        waiting = false;
                                    else
                                        successfulTrialsInRow = 0;  % Reset counter to continue
                                        waiting = false;
                                    end
                                end
                            end
                            KbReleaseWait();
                        end
                    end
                    
    end  % End of while practiceCondition && ~quitTraining
    
end  % End of while ~quitTraining

%======================================================================
%%                    TRAINING COMPLETE
%======================================================================

Screen('FillRect', window, black);
Screen('TextSize', window, 28);

completeText = ['Training complete!\n\n' ...
    'Please be sure to ask the experimenter if you have any\n' ...
    'remaining questions before the main experiment commences.\n\n' ...
    'Press any key to exit.'];

DrawFormattedText(window, completeText, 'center', 'center', white);
Screen('Flip', window);

KbReleaseWait();
KbStrokeWait();

cleanup(isEyelink);
fprintf('\n=== TRAINING SESSION COMPLETE ===\n');

%======================================================================
%%                    CLEANUP FUNCTION
%======================================================================
function cleanup(isEyelink)
    if isEyelink
        try
            Eyelink('StopRecording');
            Eyelink('Shutdown');
        catch
        end
    end
    try
        PsychPortAudio('Close');  % Close all audio handles
    catch
    end
    Priority(0);
    ListenChar(0);  % Re-enable keyboard to MATLAB
    ShowCursor;
    
    % RESTORE macOS alert volume
    try
        system(sprintf('osascript -e "set volume alert volume %d"', originalAlertVolume));
    catch
        system('osascript -e "set volume alert volume 100"');
    end
    
    sca;
end
