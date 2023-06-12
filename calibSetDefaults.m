function calib = calibSetDefaults()

%set default parameters 

calib.CavNumb = 5;  %number of cavities to test for Thevenins
calib.Attenuation = 25; % or 25?? test that 25 is okay % MEMR click should match this
% pick whatever has good SNR but it does not distort
calib.Vref  = 1; 
calib.BufferSize = 2048;
calib.SamplingRate = 48.828125; %kHz
calib.Averages = 256;
calib.ThrowAway = 4;
calib.doInfResp = 0;
% calib.positions = [83, 54.3, 40, 25.6, 18.5]; % Putt instructions
% calib.positions = [68.5, 56.5, 42, 35, 27.25]; % ER10X lengths
calib.positions = [82.97, 54.24, 40.06, 25.59, 18.48]; % measured length
calib.doFilt = 0;
calib.RZ6ADdelay = 97; % 98; % Samples
calib.electricAcousticPolarity = -1; 

calib.CavTemp = 22.6; % in C degree
calib.CavDiam = 0.796; % cm 
%calib.CavDiam = 0.794; % cm 

calib.f_err = [2 8]; % range of freq over which Thevenin calibration error is computed 
