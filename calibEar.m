%% Ear calibration following probe calibration
[FileName,PathName,FilterIndex] = uigetfile(strcat('./PROBECAL/Calib_Ph*', date, '*.mat'),...
    'Please pick DRIVE PROBE CALIBRATION file to use');
probefile = fullfile(PathName, FileName);
load(probefile);

% try
%     % Initialize ER-10X  (Also needed for ER-10C for calibrator)
%     p10x = genpath('C:\Experiments\ER-10X\MATLABAPI\Matlab\');
%     addpath(p10x);
%     loaded = ER10XConnectLoadLib('C:\Experiments\ER-10X\MATLABAPI\');
%     [err, ER10XHandle] = er10x_open();
%     fprintf(1, 'Result of ER10_X_OPEN: %s\n', err);
%     if strcmp(err, 'ER10X_ERR_OK')
%         fprintf('Continuing...\n');
%     else
%         error('Something wrong! Could not open ER10X!');
%     end
%     err = er10x_connect(ER10XHandle);
%     fprintf(1, 'Result of ER10_X_CONNECT: %s\n', err);
%     if strcmp(err, 'ER10X_ERR_OK')
%         fprintf('Continuing...\n');
%     else
%         error('Something wrong! Could not connect to ER10X!');
%     end

% Initializing TDT
fig_num=99;
GB_ch=1;
FS_tag = 3;
[f1RZ,RZ,~]=load_play_circuit_Nel2(FS_tag,fig_num,GB_ch);

probeIndex = 0;
gain = 40; % dB
%     temperatureF = 0; % Turn off heater
%     er10x_set_gain(ER10XHandle,probeIndex,gain);
%     er10x_set_output_limiter(ER10XHandle, 0); % Disable output limiter
%     er10x_output_limiter_confirm_disable(ER10XHandle); % Confirm output limiter off
%     er10x_set_mic_response(ER10XHandle, probeIndex, 1); % Flat frequency response
%     er10x_set_heater_temperature(ER10XHandle,probeIndex,temperatureF);

%     % Initializing TDT
%     % Specify path to cardAPI here
%     pcard = genpath('C:\Experiments\cardAPI\');
%     addpath(pcard);
%     card = initializeCard;

Fs = calib.SamplingRate * 1000;
driver = calib.driver;

subj = input('Please subject ID:', 's');
earflag = 1;
while earflag == 1
    ear = input('Please enter which ear (L or R):', 's');
    switch ear
        case {'L', 'l', 'Left', 'left', 'LEFT'}
            earname = strcat(ear, 'Ear');
            earlabel = 'L';
            earflag = 0;
        case {'R', 'r', 'Right','right', 'RIGHT'}
            earname = strcat(ear, 'Ear');
            earlabel = 'R';
            earflag = 0;
        otherwise
            fprintf(2, 'Unrecognized ear type! Try again!');
    end
end

% The button section is just so you can start the program, go into the
% booth and run yourself as the subject
% Ask if we want a delay (for running yourself)
button = input('Do you want a 10 second delay? (Y or N):', 's');
switch button
    case {'Y', 'y', 'yes', 'Yes', 'YES'}
        DELAY_sec=10;
        fprintf(1, '\n%.f seconds until START...\n',DELAY_sec);
        pause(DELAY_sec)
        fprintf(1, '\nWe waited %.f seconds ...\nStarting Stimulation...\n',DELAY_sec);
    otherwise
        fprintf(1, '\nStarting Stimulation...\n');
end

% Make directory to save results if it doesn't already exist
paraDir = './EARCAL/';
% whichScreen = 1;
addpath(genpath(paraDir));
if(~exist(strcat(paraDir,'\',subj),'dir'))
    mkdir(strcat(paraDir,'\',subj));
end
respDir = strcat(paraDir,'\',subj,'\');

calib.subj = subj;
calib.ear = earlabel;

% Make click
vo = clickStimulus(calib.BufferSize);
buffdata = zeros(2, numel(vo));
buffdata(driver, :) = vo; % The other source plays nothing

% Check for clipping and load to buffer
if(any(abs(buffdata(driver, :)) > 1))
    error('What did you do!? Sound is clipping!! Cannot Continue!!\n');
end


%% Set attenuation and play
drop = calib.Attenuation;

% Load the 2ch variable data into the RZ6:
invoke(RZ, 'WriteTagVEX', 'datainL', 0, 'F32', buffdata(1, :));
invoke(RZ, 'WriteTagVEX', 'datainR', 0, 'F32', buffdata(2, :));
% Set the delay of the sound
invoke(RZ, 'SetTagVal', 'onsetdel',100); % onset delay is in ms
playrecTrigger = 1;
% Set attenuations
rc = PAset([0, 0, drop, drop]);
% Set total length of sample
resplength = size(buffdata,2) + calib.RZ6ADdelay; % How many samples to read from OAE buffer
invoke(RZ, 'SetTagVal', 'nsamps', resplength);

for n = 1:(calib.Averages + calib.ThrowAway)
    %Start playing from the buffer:
    invoke(RZ, 'SoftTrg', playrecTrigger);
    currindex = invoke(RZ, 'GetTagVal', 'indexin');
    
    while(currindex < resplength)
        currindex=invoke(RZ, 'GetTagVal', 'indexin');
    end
    
    vin = invoke(RZ, 'ReadTagVex', 'dataout', 0, resplength,...
        'F32','F64',1);
    
    % Save data
    if (n > calib.ThrowAway)
        vins_ear(n-calib.ThrowAway,:) = vin((calib.RZ6ADdelay + 1):end);
    end
    
    % Get ready for next trial
    invoke(RZ, 'SoftTrg', 8); % Stop and clear "OAE" buffer
    %Reset the play index to zero:
    invoke(RZ, 'SoftTrg', 5); %Reset Trigger
end
% pause(0.05);

%     vins_ear = playCapture2(buffdata, card, calib.Averages,...
%         calib.ThrowAway, drop, drop, 1);
%
%




if calib.doFilt
    % High pass at 100 Hz using IIR filter
    [b, a] = butter(4, 100 * 2 * 1e-3/calib.SamplingRate, 'high');
    vins_ear = filtfilt(b, a, vins_ear')';
end
vins_ear = demean(vins_ear, 2);
energy = squeeze(sum(vins_ear.^2, 2));
good = energy < median(energy) + 2*mad(energy, 1);
vavg = squeeze(mean(vins_ear(good, :), 1));
Vavg = rfft(vavg');
calib.vavg_ear = vavg;

% Apply calibartions to convert voltage to pressure
% For ER-10X, this is approximate
mic_sens = 50e-3; % mV-RMS/Pa
mic_gain = db2mag(gain); % +6 dB for "balanced cable"
P_ref = 20e-6 * sqrt(2); % Reference pressure in peak Pa (not RMS)
DR_onesided = 1;
mic_output_V = Vavg / (DR_onesided * mic_gain);
output_Pa = mic_output_V/mic_sens;
outut_Pa_20uPa_per_Vpp = output_Pa / P_ref; % unit: 20 uPa / Vpeak

freq = 1000*linspace(0,calib.SamplingRate/2,length(Vavg))';

Vo = rfft(calib.vo)*5*db2mag(-1 * calib.Attenuation);
calib.EarRespH =  outut_Pa_20uPa_per_Vpp ./ Vo; %save for later



%% Plot data
figure(1);
ax(1) = subplot(2, 1, 1);
semilogx(calib.freq, db(abs(calib.EarRespH)), 'linew', 2);
ylabel('Response (dB re: 20 \mu Pa / V_{peak})', 'FontSize', 16);
ax(2) = subplot(2, 1, 2);
semilogx(calib.freq, unwrap(angle(calib.EarRespH), [], 1), 'linew', 2);
xlabel('Frequency (Hz)', 'FontSize', 16);
ylabel('Phase (rad)', 'FontSize', 16);
linkaxes(ax, 'x');
legend('show');
xlim([100, 24e3]);

%% Calculate Ear properties
calib = findHalfWaveRes(calib);
calib.Zec_raw = ldimp(calib.Zs, calib.Ps, calib.EarRespH);
% calib.Zec = zsmo(calib.Zec, z_tube(calib.CavTemp, calib.CavDiam),...
%     calib.SamplingRate * 1000);
calib.Zec = calib.Zec_raw;

% decompose pressures
calib.fwb = 0.55;% bandwidth/Nyquist freq of freq.domain window

% *ec: Ear canal
% *s: Source
% R*: Reflectance
% Z*: Impedance
% Pfor: Forward pressure
% Prev: Reverse pressure
% Pinc: Incident pressure

[calib.Rec, calib.Rs, calib.Rx, calib.Pfor, calib.Prev, calib.Pinc, ...
    calib.Px, calib.Z0, calib.Zi, calib.Zx] = decompose(calib.Zec,...
    calib.Zs, calib.EarRespH, calib.Ps, calib.fwb, ...
    calib.CavTemp, calib.CavDiam);

% Check for leaks as in Groon et al
ok = find (calib.freq >= 200 & calib.freq <= 500);
calib.A_lf =  mean(1-(abs(calib.Rec(ok))).^2);
fprintf(1, 'Low-frequency absorbance: %2.3f\n', calib.A_lf);
calib.Yphase_lf = mean(cycs(1./calib.Zec(ok)))*360;
fprintf(1, 'Low-frequency admittance phase: %2.3f%c\n',...
    calib.Yphase_lf, char(176));


if (calib.A_lf > 0.29)
    h = warndlg ('Sound-leak alert! Low-frequency absorbance > 0.29');
    waitfor(h);
end

if (calib.Yphase_lf < 44)
    h = warndlg ('Sound-leak alert! Low-frequency admittance phase < 44 degrees');
    waitfor(h);
end

%% Plot Ear Absorbance
figure(2);
semilogx(calib.freq * 1e-3, 100*(1 - abs(calib.Rec).^2), 'linew', 2);
xlabel('Frequency (Hz)', 'FontSize', 16);
ylabel('Absorbance (%)', 'FontSize', 16);
xlim([0.2, 8]); ylim([0, 100]);
set(gca, 'FontSize', 16, 'XTick',[0.25, 0.5, 1, 2, 4, 8]);

%% Save Ear Calculations
datetag = datestr(clock);
calib.date = datetag;
datetag(strfind(datetag,' ')) = '_';
datetag(strfind(datetag,':')) = '_';
fname = strcat(respDir,'Calib_',calib.drivername,calib.device,'_',...
    subj,earname,'_',datetag, '.mat');
save(fname,'calib');
%% Close TDT, ER-10X connections etc. and cleanup

close_play_circuit(f1RZ, RZ);
%% Close ER-10X connection
%     closeCard(card);
%     temperatureF = 86; % 30C
%     er10x_set_heater_temperature(ER10XHandle,probeIndex,temperatureF);
%     err = er10x_disconnect(ER10XHandle);
%     if strcmp(err, 'ER10X_ERR_OK')
%         fprintf('Continuing...\n');
%     else
%         error('Something wrong! Could not close ER10X!');
%     end
%     [err, ER10XHandle] = er10x_close(ER10XHandle);
%     if strcmp(err, 'ER10X_ERR_OK')
%         fprintf('Continuing...\n');
%     else
%         error('Something wrong! Could not close ER10X!');
%     end
%     ER10XCloseAll();
%     ER10XConnectUnloadLib();
%     rmpath(p10x);
%     rmpath(pcard);
% catch me
%     closeCard(card);
%     temperatureF = 86; % 30C
%     er10x_set_heater_temperature(ER10XHandle,probeIndex,temperatureF);
%     err = er10x_disconnect(ER10XHandle);
%     if strcmp(err, 'ER10X_ERR_OK')
%         fprintf('Continuing...\n');
%     else
%         error('Something wrong! Could not close ER10X!');
%     end
%     [err, ER10XHandle] = er10x_close(ER10XHandle); %#ok<ASGLU>
%     if strcmp(err, 'ER10X_ERR_OK')
%         fprintf('Continuing...\n');
%     else
%         error('Something wrong! Could not close ER10X!');
%     end
%     ER10XCloseAll();
%     ER10XConnectUnloadLib();
%     rmpath(p10x);
%     rmpath(pcard);
%     close all hidden;
%     rethrow(me);
% end
