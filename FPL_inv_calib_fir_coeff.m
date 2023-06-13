function b = FPL_inv_calib_fir_coeff(subj, ear, driver)
mainDir = 'C:\Users\Heinz Lab - NEL2\Desktop\OAEs\sweptDPOAE\'; 

FPL_EARCAL_dir = 'C:\Users\Heinz Lab - NEL2\Desktop\OAEs\FPLclick\EARCAL\'; 
cd(FPL_EARCAL_dir); 
checkDir = dir(subj); 
if isempty(checkDir)
    fprintf(2,'You need to run an FPL calibration for this subject first!\n');
    return
else
    cd([FPL_EARCAL_dir subj]); 
end

driver_files = dir(sprintf('Calib_Ph%sER-10X_%s%sEar_*.mat', driver, subj, ear));
% use most recent file 
[~ ,filenum] = max([driver_files(:).datenum]); 
load(driver_files(filenum).name); 

freq_Hz=calib.freq;
dBspl_atten = calib.Attenuation; 
EarRespH_complex = calib.EarRespH; 

%% figure out inverse filter gains
% ER2 technical specs says gain at 1V rms should be 100 dB
% https://www.etymotic.com/auditory-research/insert-earphones-for-research/er2.html
% We are playing = 10V pp (TDT max Output)
% RMS= 10/sqrt(2); : should be ~(100+17)=~117 dB
% 117 dB: too loud. So set ideal dB SPL to something between 90-100 dB
dBSPL_ideal= 105; 
filter_gain= dBSPL_ideal-(db(abs(EarRespH_complex))+dBspl_atten);
% dBSPL_ideal= 105; 
% filter_gain= dBSPL_ideal-dBspl_at0dB_atten;

% Suppress high frequency gain (Taper to zero?)
freq_near16k= dsearchn(freq_Hz, 16e3);
filter_gain(freq_near16k:end)= linspace(filter_gain(freq_near16k), 0, numel(filter_gain)-freq_near16k+1);


%% design filter
fs=  48828.125;
Nfilter= 255;
b = fir2(Nfilter, freq_Hz/(fs/2), db2mag(filter_gain));

figure(6)
freqz(b,1,2056, fs)
title('Inverted gain filter')

b=b'; 
cd(mainDir); 
end
