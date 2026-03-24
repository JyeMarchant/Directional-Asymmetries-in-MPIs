function showRestScreen(window, currentBlock, totalBlocks, white, xCenter, yCenter)
    % Display rest screen between blocks with progress bar
    % 
    % Parameters:
    %   window - PsychToolbox window pointer
    %   currentBlock - current block number (just completed)
    %   totalBlocks - total number of blocks in experiment
    %   white - white color value for text
    %   xCenter, yCenter - center coordinates (optional, will auto-detect if not provided)
    
    % Handle optional center coordinates - auto-detect if not provided
    if nargin < 6
        windowRect = Screen('Rect', window);
        windowWidth = windowRect(3);
        windowHeight = windowRect(4);
        xCenter = windowWidth / 2;
        yCenter = windowHeight / 2;
    end
    
    Screen('FillRect', window, 0); % Black background
    
    if currentBlock <= totalBlocks
        blocksCompleted = currentBlock;  % currentBlock is the block we just finished
        restText = sprintf('Block %d of %d completed\n\nTake a short rest\n\nPress SPACEBAR to continue with the next block', ...
                          blocksCompleted, totalBlocks);
    else
        blocksCompleted = totalBlocks;
        restText = 'All blocks completed\n\nPress SPACEBAR to finish the experiment';
    end
    
    % Draw main text
    Screen('TextSize', window, 28);
    Screen('TextFont', window, 'Futura'); % Modern, clean font
    DrawFormattedText(window, restText, 'center', yCenter - 100, white);
    
    % Progress bar parameters
    barWidth = 400;
    barHeight = 30;
    barX = xCenter - barWidth/2;
    barY = yCenter + 50;
    
    % Colors for progress bar
    barBackground = [60, 60, 60];  % Dark grey background
    barForeground = [0, 180, 0];   % Nice green for completed portion
    barBorder = white;             % White border
    
    % Calculate progress
    progress = blocksCompleted / totalBlocks;
    filledWidth = barWidth * progress;
    
    % Draw progress bar background
    barRect = [barX, barY, barX + barWidth, barY + barHeight];
    Screen('FillRect', window, barBackground, barRect);
    
    % Draw filled portion (green)
    if filledWidth > 0
        filledRect = [barX, barY, barX + filledWidth, barY + barHeight];
        Screen('FillRect', window, barForeground, filledRect);
    end
    
    % Draw progress bar border
    Screen('FrameRect', window, barBorder, barRect, 2);
    
    % Draw progress percentage text
    Screen('TextSize', window, 20);
    Screen('TextFont', window, 'Futura'); % Modern, clean font
    progressText = sprintf('%.0f%% Complete', progress * 100);
    DrawFormattedText(window, progressText, 'center', barY + barHeight + 25, white);
    
    Screen('Flip', window);
    
    % Wait for spacebar press using multi-keyboard support (exact same logic as motion coherence)
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
end