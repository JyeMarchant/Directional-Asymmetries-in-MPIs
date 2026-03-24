function blockOrder = getCounterbalanceOrder(subjectNumber, numBlocks)
% GETCOUNTERBALANCEORDER Get counterbalanced block order for FLE experiment
%   blockOrder = getCounterbalanceOrder(subjectNumber)
%   blockOrder = getCounterbalanceOrder(subjectNumber, numBlocks)
%
%   Uses Latin square design to counterbalance 4 conditions.
%   Each condition appears equal number of times per subject.
%   
%   Conditions:
%       1 = flashbaseline    (flash alone)
%       2 = centralcue       (motion with central cue, no flash)
%       3 = flash_motion     (localize flash with motion present)
%       4 = motion_flash     (localize motion with flash present)
%
%   Input:
%       subjectNumber - Numeric subject ID (will be converted if string)
%       numBlocks     - Total number of blocks (default: 8, must be multiple of 4)
%
%   Output:
%       blockOrder - 1xnumBlocks vector of condition indices in presentation order

% Default to 8 blocks if not specified
if nargin < 2 || isempty(numBlocks)
    numBlocks = 8;
end

% Ensure numBlocks is a multiple of 4
if mod(numBlocks, 4) ~= 0
    warning('numBlocks should be a multiple of 4 for balanced counterbalancing. Rounding up.');
    numBlocks = ceil(numBlocks / 4) * 4;
end

% Latin square for 4 conditions (balanced for first-order carryover effects)
latinSquare = [
    1 2 3 4;
    2 4 1 3;
    3 1 4 2;
    4 3 2 1
];

% Convert subject number to numeric if needed
if ischar(subjectNumber) || isstring(subjectNumber)
    subjectNumber = str2double(subjectNumber);
end

% Determine which row of Latin square to use (cycles every 4 subjects)
rowIndex = mod(subjectNumber - 1, 4) + 1;

% Get the base order for this subject (4 blocks)
baseOrder = latinSquare(rowIndex, :);

% Create full block order by repeating the Latin square pattern
numRepeats = numBlocks / 4;
blockOrder = repmat(baseOrder, 1, numRepeats);

% Display the order for verification
conditionNames = {'flashbaseline', 'centralcue', 'flash_motion', 'motion_flash'};
fprintf('\n=== COUNTERBALANCE ORDER FOR SUBJECT %03d ===\n', subjectNumber);
fprintf('(%d blocks, each condition appears %d times)\n', numBlocks, numRepeats);
for i = 1:numBlocks
    fprintf('Block %d: %s\n', i, conditionNames{blockOrder(i)});
end
fprintf('=============================================\n\n');
