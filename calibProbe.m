%% Sound Source, Microphone Probe Thevenin Calibration
% Note: Calibartions need to be run seperatley for each sound source

% SH attempts to integrate with NEL

% try
% Initialize ER-10X  (Also needed for ER-10C for calibrator)
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
%    temperatureF = 0; % Turn off heater during use
%     er10x_set_gain(ER10XHandle,probeIndex,gain);
%     er10x_set_output_limiter(ER10XHandle, 0); % Disable output limiter
%     er10x_output_limiter_confirm_disable(ER10XHandle); % Confirm output limiter off
%     er10x_set_mic_response(ER10XHandle, probeIndex, 1); % Flat frequency response
%     er10x_set_heater_temperature(ER10XHandle,probeIndex,temperatureF);
%
% Initializing TDT
% Specify path to cardAPI here
%     pcard = genpath('C:\Experiments\cardAPI\');
%     addpath(pcard);
%     card = initializeCard;
%

% Initializing Calibration
calib = calibSetDefaults();
Fs = calib.SamplingRate * 1000; % to Hz

deviceflag = 1;
while deviceflag == 1
    device = input('Please enter X or C for ER-10X/ER-10C respectively:', 's');
    switch device
        case {'X', 'x'}
            device = 'ER-10X';
            deviceflag = 0;
        case {'C', 'c'}
            device = 'ER-10C';
            deviceflag = 0;
            % ER-10C has more distortion, hence attenuate by another 15 dB
            calib.Attenuation = calib.Attenuation + 15;
        otherwise
            fprintf(2, 'Unrecognized device! Try again!');
    end
end

driverflag = 1;
while driverflag == 1
    driver = input('Please enter whether you want driver 1, 2 or 3 (Aux on ER-10X):');
    switch driver
        case {1, 2}
            drivername = strcat('Ph',num2str(driver));
            driverflag = 0;
        case 3
            if strcmp(device, 'ER-10X')
                drivername = 'PhAux';
                driverflag = 0;
            else
                fprintf(2, 'Unrecognized driver! Try again!');
            end
        otherwise
            fprintf(2, 'Unrecognized driver! Try again!');
    end
end
calib.device = device;
calib.drivername = drivername;
calib.driver = driver;


% Make click
vo = clickStimulus(calib.BufferSize);
buffdata = zeros(2, numel(vo));
buffdata(driver, :) = vo; % The other source plays nothing
calib.vo = vo;
vins = zeros(calib.CavNumb, calib.Averages, calib.BufferSize);
calib.vavg = zeros(calib.CavNumb, calib.BufferSize);

%     err = er10x_move_to_position_and_wait(ER10XHandle, 0, 20000);
%     fprintf(1, 'Result of moving to position 1: %s\n', err);
%     if strcmp(err, 'ER10X_ERR_OK')
%         fprintf('Continuing...\n');
%     else
%         error('Something wrong! Calibration aborted!');
%     end

for m = 1:calib.CavNumb
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
    vins(m,n-calib.ThrowAway,:) = vin((calib.RZ6ADdelay + 1):end);
    end
    
    % Get ready for next trial
    invoke(RZ, 'SoftTrg', 8); % Stop and clear "OAE" buffer
    %Reset the play index to zero:
    invoke(RZ, 'SoftTrg', 5); %Reset Trigger
    end 
    % pause(0.05);
    
    %compute the average
    
    if calib.doFilt
        % High pass at 100 Hz using IIR filter
        [b, a] = butter(4, 100 * 2 * 1e-3/calib.SamplingRate, 'high');
        vins(m, :, :) = filtfilt(b, a, squeeze(vins(m, :, :))')';
    end
    vins(m, :, :) = demean(squeeze(vins(m, :, :)), 2);
    energy = squeeze(sum(vins(m, :, :).^2, 3));
    good = energy < median(energy) + 2*mad(energy);
    vavg = squeeze(mean(vins(m, good, :), 2));
    calib.vavg(m, :) = vavg;
    Vavg = rfft(vavg);
    
    % Apply calibartions to convert voltage to pressure
    % For ER-10X, this is approximate
    mic_sens = 50e-3; % mV/Pa. TO DO: change after calibration
    mic_gain = db2mag(gain); % +6 for balanced cable
    P_ref = 20e-6;
    DR_onesided = 1;
    mic_output_V = Vavg / (DR_onesided * mic_gain);
    output_Pa = mic_output_V/mic_sens;
    outut_Pa_20uPa_per_Vpp = output_Pa / P_ref; % unit: 20 uPa / Vpeak
    
    freq = 1000*linspace(0,calib.SamplingRate/2,length(Vavg))';
    calib.freq = freq;
    
    % CARD MAT2VOLTS = 5.0
    Vo = rfft(calib.vo)*5*db2mag(-1 * calib.Attenuation);
    calib.CavRespH(:,m) =  outut_Pa_20uPa_per_Vpp ./ Vo; %save for later
    
    if m+1 <= calib.CavNumb
        fprintf('Move to next tube! \n');
            % Tell user to make sure calibrator is set correctly
        uiwait(warndlg('MOVE TO THE NEXT SMALLEST TUBE','SET TUBE WARNING','modal'));
    end
    

    
    
    %         if m < calib.CavNumb
    %             err = er10x_move_to_position_and_wait(ER10XHandle, m, 20000);
    %             fprintf(1, 'Result of moving to position %d: %s\n', m+1, err);
    %             if strcmp(err, 'ER10X_ERR_OK')
    %                 fprintf('Continuing...\n');
    %             else
    %                 error('Something wrong! Calibration aborted!');
    %             end
    %
    %         else
    %             if (calib.doInfResp == 1)
    %                 out2 = input(['Done with ER-10X cavities.. Move to infinite tube!\n',...
    %                     'Continue? Press n to stop or any other key to go on:'], 's');
    %             end
    %         end
end

%     if(calib.doInfResp == 1)
%         % FINISH AFTER CHECKING
%         calib.InfRespH = outut_Pa_20uPa_per_Vpp ./ Vo; %save for later
%     end


%% Plot data
figure(11);
ax(1) = subplot(2, 1, 1);
semilogx(calib.freq, db(abs(calib.CavRespH)) + 20, 'linew', 2);
ylabel('Response (dB re: 20 \mu Pa / V_{peak})', 'FontSize', 16);
ax(2) = subplot(2, 1, 2);
semilogx(calib.freq, unwrap(angle(calib.CavRespH), [], 1), 'linew', 2);
xlabel('Frequency (Hz)', 'FontSize', 16);
ylabel('Phase (rad)', 'FontSize', 16);
linkaxes(ax, 'x');
legend('show');
xlim([20, 24e3]);
hold off; 
%% Compute Thevenin Equivalent Pressure and Impedance

%set up some variables
irr = 1; %ideal cavity reflection

%  calc the cavity length
calib.CavLength = cavlen(calib.SamplingRate,calib.CavRespH, calib.CavTemp);
if (irr)
    la = [calib.CavLength 1]; %the one is reflection fo perfect cavit
else
    la = calib.CavLength; %#ok<UNRCH>
end

df=freq(2)-freq(1);
jef1=1+round(calib.f_err(1)*1000/df);
jef2=1+round(calib.f_err(2)*1000/df);
ej=jef1:jef2; %limit freq range for error calc

calib.Zc = cavimp(freq, la, irr, calib.CavDiam, calib.CavTemp); %calc cavity impedances

%% Plot impedances
% It's best to have the set of half-wave resonant peaks (combined across
% all cavities and including all harmonics) distributed as uniformly as
% possible across the frequency range of interest.
figure(12)
plot(calib.freq/1000,dB(calib.Zc)); hold on
xlabel('Frequency kHz')
ylabel('Impedance dB')
%
pcav = calib.CavRespH;
options = optimset('TolFun', 1e-12, 'MaxIter', 1e5, 'MaxFunEvals', 1e5);
la=fminsearch(@ (la) thverr(la,ej, freq, pcav, irr, calib.CavDiam, calib.CavTemp),la, options);
calib.Error = thverr(la, ej, freq, pcav, irr, calib.CavDiam, calib.CavTemp);

calib.Zc=cavimp(freq,la, irr, calib.CavDiam, calib.CavTemp);  % calculate cavity impedances
[calib.Zs,calib.Ps]=thvsrc(calib.Zc,pcav); % estimate zs & ps

plot(freq/1000,dB(calib.Zc),'--'); %plot estimated Zc

calib.CavLength = la;

if ~(calib.Error >= 0 && calib.Error <=1)
    h = warndlg ('Calibration error out of range!');
    waitfor(h);
end

%% Save calib.Zs and Ps - you can measure them weekly/daily and load

datetag = datestr(clock);
calib.date = datetag;
datetag(strfind(datetag,' ')) = '_';
datetag(strfind(datetag,':')) = '_';
fname = strcat('./PROBECAL/Calib_',drivername,device,datetag, '.mat');
save(fname,'calib');

%% Close TDT, ER-10X connections etc. and cleanup

close_play_circuit(f1RZ, RZ);

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

% just before the subject arrives

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
%     rethrow(me);
% end