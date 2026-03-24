function [x, y] = getEyelinkCoordinates(el, eyeUsed)
    % Get current eye position from EyeLink
    % Returns NaN for invalid data
    %
    % Parameters:
    %   el - EyeLink structure (optional, only needed if el.MISSING_DATA is used)
    %   eyeUsed - eye to track (0=LEFT, 1=RIGHT, -1=invalid)
    %
    % Returns:
    %   x, y - gaze coordinates in pixels, or NaN if invalid
    
    if Eyelink('NewFloatSampleAvailable') > 0
        evt = Eyelink('NewestFloatSample');
        if eyeUsed ~= -1 % if eye selection is not invalid
            % get current gaze position from sample
            x = evt.gx(eyeUsed+1); % +1 as we're accessing MATLAB array
            y = evt.gy(eyeUsed+1);
            % do we have valid data and is the pupil visible?
            % Use standard EyeLink missing data constant if el not provided
            MISSING_DATA = -32768;
            if nargin >= 1 && isfield(el, 'MISSING_DATA')
                MISSING_DATA = el.MISSING_DATA;
            end
            
            if x == MISSING_DATA || y == MISSING_DATA || evt.pa(eyeUsed+1) <= 0
                x = NaN;
                y = NaN;
            end
        else
            x = NaN;
            y = NaN;
        end
    else
        x = NaN;
        y = NaN;
    end
end