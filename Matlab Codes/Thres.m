clear;
%Training file
CSV_file = preprocessor(csvread("Dataset/WithSeq/indoor1.csv"), 1);
%Test file
CSV_file_pred = preprocessor(csvread("Dataset/WithSeq/outdoor1.csv"), 2);

total_samples = size(CSV_file);

% numFeatures = 4;
numHiddenUnits = 30;
numClasses = 5;

% layers = [
%     sequenceInputLayer(numFeatures)
%     lstmLayer(numHiddenUnits,'OutputMode','sequence')
%     fullyConnectedLayer(numClasses)
%     softmaxLayer
%     classificationLayer];

layers = [...
        sequenceInputLayer(4)
    lstmLayer(numHiddenUnits, 'OutputMode', 'sequence')
    fullyConnectedLayer(numClasses)
    softmaxLayer
    classificationLayer];

maxEpochs = 15;
miniBatchSize = 5;

%  options = trainingOptions('adam', ...
%      'ExecutionEnvironment','cpu', ...
%      'GradientThreshold',1, ...
%      'MaxEpochs',maxEpochs, ...
%      'MiniBatchSize',miniBatchSize, ...
%      'SequenceLength','longest', ...
%      'Shuffle','never', ...
%      'Verbose',0, ...
%      'GradientThreshold',1, ...
%     'Plots','training-progress');

options = trainingOptions('adam', ...
    'ExecutionEnvironment', 'cpu', ...
    'GradientThreshold', 0.001, ...
    'MaxEpochs', maxEpochs, ...
    'MiniBatchSize', miniBatchSize, ...
    'SequenceLength', 'longest', ...
    'Shuffle', 'never', ...
    'Verbose', 0, ...
    'Plots', 'training-progress');

walking = magic(0);
walking_up = magic(0);
walking_down = magic(0);
sitting = magic(0);
standing = magic(0);

for a = 1:total_samples(1, 1)
    row = CSV_file(a, :);
    inertial_values = row(3:6);
    label = row(8);

    if label == 1
        walking = [walking; inertial_values];
    end

    if label == 2
        walking_up = [walking_up; inertial_values];
    end

    if label == 3
        walking_down = [walking_down; inertial_values];
    end

    if label == 4
        sitting = [sitting; inertial_values];
    end

    if label == 5
        standing = [standing; inertial_values];
    end

end

clear row;

Xtrain = cell(0, 0);
Xtrain = {transpose(walking); transpose(walking_up); transpose(walking_down); transpose(sitting); transpose(standing)};

Wal_label = zeros(1, getSize(walking));

for i = 1:size(walking)
    Wal_label(i) = 1;
end

Walup_label = zeros(1, getSize(walking_up));

for i = 1:size(walking_up)
    Walup_label(i) = 2;
end

Waldown_label = zeros(1, getSize(walking_down));

for i = 1:size(walking_down)
    Waldown_label(i) = 3;
end

sit_label = zeros(1, getSize(sitting));

for i = 1:size(sitting)
    sit_label(i) = 4;
end

stand_label = zeros(1, getSize(standing));

for i = 1:size(standing)
    stand_label(i) = 5;
end

%c = row1;
%c = [cell; row2]

Wal_label = categorical(Wal_label);
Walup_label = categorical(Walup_label);
Waldown_label = categorical(Waldown_label);
sit_label = categorical(sit_label);
stand_label = categorical(stand_label);

Ytrain = {Wal_label; Walup_label; Waldown_label; sit_label; stand_label};

%Model training
net = trainNetwork(Xtrain, Ytrain, layers, options);

%Activity classification
Xtest = transpose(CSV_file_pred(:, [3:6]));
Ypred = classify(net, Xtest);
Ypred = double(Ypred);
Ypred = transpose(Ypred);
Xtest = transpose(Xtest);

%%Threshold calculator

RSSI = CSV_file_pred(:, 2);
label = Ypred;
len = size(RSSI);
len = len(1, 1);

%Acc=sgolayfilt(Acc_Mag,6,21);
RSSI = sgolayfilt(RSSI, 6, 21);
Acc = Xtest(:, 1);
%walking
Acc_walk = [];
RSSI_walk = [];
Last_thres_walk = -40;
Threshold_walk = [-40];
Global_min_walk = [1];
size_walk = 0;
lqe_walk = [];

%walking_up
Acc_walk_up = [];
RSSI_walk_up = [];
Last_thres_walk_up = -40;
Threshold_walk_up = [-40];
Global_min_walk_up = [1];
size_walk_up = 0;
lqe_walk_up = [];

%walking_down
Acc_walk_down = [];
RSSI_walk_down = [];
Last_thres_walk_down = -40;
Threshold_walk_down = [-40];
Global_min_walk_down = [1];
size_walk_down = 0;
lqe_walk_down = [];

%siting
Acc_sitting = [];
RSSI_sitting = [];
Last_thres_sitting = -40;
Threshold_sitting = [-40];

%standing

Acc_standing = [];
RSSI_standing = [];
Last_thres_standing = -40;
Threshold_standing = [-40];

%TPL array
TPL = [-5];

for itr = 1:len

    if (label(itr, 1) == 1)

        if (size_walk ~= 0)
            size_walk = size_walk + 1;
            Acc_walk = [Acc_walk; Acc(itr, 1)];
            RSSI_walk = [RSSI_walk; RSSI(itr, 1)];

            if (mod(size_walk + 1, 30) == 0)
                temp = size(Global_min_walk);
                temp = temp(1, 1);
                prev_gmin = Global_min_walk(temp, 1);
                g_idx = g_min(Acc_walk, prev_gmin);
                Last_thres_walk = threshold_calc(RSSI_walk, islocalmax(RSSI_walk), prev_gmin);

                temp_tpl = ((RSSI(g_idx, 1) + RSSI(prev_gmin, 1))/2)+Last_thres_walk;
                TPL=[TPL;temp_tpl];

                lqe = link_quality(Acc_walk, prev_gmin, g_idx);
                lqe_walk = [lqe_walk, lqe];

                Global_min_walk = [Global_min_walk; g_idx];
                Threshold_walk = [Threshold_walk; Last_thres_walk];
                clear temp;
                clear prev_gmin;
                clear g_idx;
            end

        elseif (size_walk == 0)
            size_walk = size_walk + 1;
            Acc_walk = [Acc_walk; Acc(itr, 1)];
            RSSI_walk = [RSSI_walk; RSSI(itr, 1)];
        end

    elseif (label(itr, 1) == 2)

        if (size_walk_up ~= 0)
            size_walk_up = size_walk_up + 1;
            Acc_walk_up = [Acc_walk_up; Acc(itr, 1)];
            RSSI_walk_up = [RSSI_walk_up; RSSI(itr, 1)];

            if (mod(size_walk_up + 1, 30) == 0)
                temp = size(Global_min_walk_up);
                temp = temp(1, 1);
                prev_gmin = Global_min_walk_up(temp, 1);
                g_idx = g_min(Acc_walk_up, prev_gmin);
                Last_thres_walk_up = threshold_calc(RSSI_walk_up, islocalmax(RSSI_walk_up), prev_gmin);


                temp_tpl = ((RSSI(g_idx, 1) + RSSI(prev_gmin, 1))/2)+Last_thres_walk_up;
                TPL=[TPL;temp_tpl];


                lqe = link_quality(Acc_walk_up, prev_gmin, g_idx);
                lqe_walk_up = [lqe_walk_up, lqe];

                Global_min_walk_up = [Global_min_walk_up; g_idx];
                Threshold_walk_up = [Threshold_walk_up; Last_thres_walk_up];
                clear temp;
                clear prev_gmin;
                clear g_idx;
            end

        elseif (size_walk_up == 0)
            size_walk_up = size_walk_up + 1;
            Acc_walk_up = [Acc_walk_up; Acc(itr, 1)];
            RSSI_walk_up = [RSSI_walk_up; RSSI(itr, 1)];
        end

    elseif (label(itr, 1) == 3)

        if (size_walk_down ~= 0)
            size_walk_down = size_walk_down + 1;
            Acc_walk_down = [Acc_walk_down; Acc(itr, 1)];
            RSSI_walk_down = [RSSI_walk_down; RSSI(itr, 1)];

            if (mod(size_walk_down + 1, 30) == 0)
                temp = size(Global_min_walk_down);
                temp = temp(1, 1);
                prev_gmin = Global_min_walk_down(temp, 1);
                g_idx = g_min(Acc_walk_down, prev_gmin);
                Last_thres_walk_down = threshold_calc(RSSI_walk_down, islocalmax(RSSI_walk_down), prev_gmin);

                temp_tpl = ((RSSI(g_idx, 1) + RSSI(prev_gmin, 1))/2)+Last_thres_walk_down;
                TPL=[TPL;temp_tpl];

                lqe = link_quality(Acc_walk_down, prev_gmin, g_idx);
                lqe_walk = [lqe_walk_down, lqe];

                Global_min_walk_down = [Global_min_walk_down; g_idx];
                Threshold_walk_down = [Threshold_walk_down; Last_thres_walk_down];
                clear temp;
                clear prev_gmin;
                clear g_idx;
            end

        elseif (size_walk_down == 0)
            size_walk_down = size_walk_down + 1;
            Acc_walk_down = [Acc_walk_down; Acc(itr, 1)];
            RSSI_walk_down = [RSSI_walk_down; RSSI(itr, 1)];
        end

    elseif (label(itr, 1) == 4)
        Acc_sitting = [Acc_sitting; Acc(itr, 1)];
        RSSI_sitting = [RSSI_sitting; RSSI(itr, 1)];
        size_arr = size(Acc_sitting);
        size_arr = size_arr(1, 1);

        if (size_arr > 4)
            sum_RSSI = 0;
            count = 0;

            for idx = size_arr - 4:size_arr
                sum_RSSI = sum_RSSI + RSSI_sitting(idx, 1);
                count = count + 1;
            end

            Last_thres_sitting = sum_RSSI / count;
            TPL = [TPL;Last_thres_sitting];

            Threshold_sitting = [Threshold_sitting; Last_thres_sitting];

        end

    elseif (label(itr, 1) == 5)
        Acc_standing = [Acc_standing; Acc(itr, 1)];
        RSSI_standing = [RSSI_standing; RSSI(itr, 1)];
        size_arr = size(Acc_standing);
        size_arr = size_arr(1, 1);

        if (size_arr > 5)
            sum_RSSI = 0;
            count = 0;

            for idx = size_arr - 4:size_arr
                sum_RSSI = sum_RSSI + RSSI_standing(idx, 1);
                count = count + 1;
            end

            Last_thres_standing = sum_RSSI / count;
            TPL = [TPL;Last_thres_standing];
            Threshold_standing = [Threshold_standing; Last_thres_standing];
        end

    end

end



Average_TPL = mean(transpose(TPL));


%global minimum algorithm
function index = g_min(Array, s)
    min = 1000;
    arr_size = size(Array);
    arr_size = arr_size(1, 1);

    for itr = s:1:arr_size

        if (min > Array(itr, 1))
            min = Array(itr, 1);
            index = itr;
        end

    end

end

%Threshold calculation
function avg = threshold_calc(Smooth_RSSI, local_max_RSSI, s)
    count = 1;
    sum = 0;

    arr_size = size(Smooth_RSSI);
    arr_size = arr_size(1, 1);

    for itr = s:1:arr_size

        if (local_max_RSSI(itr, 1) == 1)
            sum = sum + Smooth_RSSI(itr, 1);
            count = count + 1;
        end

    end

    avg = sum / (count - 1);

    if isnan(avg)
        avg = mean(Smooth_RSSI);
    end

end

function noofsamples = getSize(activity)
    s = size(activity);
    noofsamples = s(1, 1);
end

function file = preprocessor(CSV_file, var)
    Acc_x = CSV_file(:, 3);
    Acc_y = CSV_file(:, 4);
    Acc_z = CSV_file(:, 5);

    total_samples = size(CSV_file);
    Acc_Mag = zeros(total_samples(1, 1), 1);

    %Calculating Accleration magnitude from Acc_X,Acc_Y,Acc_Z
    for itr = 1:total_samples(1, 1)
        sum = (Acc_x(itr, 1)^2) + (Acc_y(itr, 1)^2) + (Acc_z(itr, 1)^2);
        Acc_Mag(itr, 1) = sum^0.5;
    end

    Acc_Mag = sgolayfilt(Acc_Mag, 6, 21);

    left = CSV_file(:, [1:2]);

    if var == 1
        right = CSV_file(:, [6:10]);
    else
        right = CSV_file(:, [6:9]);
    end

    file = left;
    file = [file Acc_Mag];
    file = [file right];

end

function lqe = link_quality(Array, s, e)
    Array = transpose(Array);
    numerator = (e - s) / 10;
    localMax = islocalmax(Array);
    first_maxima = 0;
    last_maxima = 0;

    for itr = s + 1:e - 1

        if localMax(itr) == 1
            first_maxima = itr;
            break
        end

    end

    for itr = e - 1:-1:s + 1

        if localMax(itr) == 1
            last_maxima = itr;
        end

    end

    if last_maxima - first_maxima ~= 0
        lqe = numerator / ((last_maxima - first_maxima) / 10);
    else
        lqe = 0;
    end

end
