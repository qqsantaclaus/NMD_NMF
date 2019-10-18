ftoread = 'speech_dict_2570_all.csv';
S = csvread(ftoread);

ftoread = 'noise_dict_2570_all.csv';
N = csvread(ftoread);

ftoread = './noise_dict/noise_dict_1000_ipad_office1.csv';
AN = csvread(ftoread);

ftoread = './test_dict/test_dict_2570_f10_script5_ipad_office1.csv';
Z = csvread(ftoread);
sub_Z = Z(:, 10:110)

A = [S N AN];
size(A)
L = 10;
lambda_s = 1.6;
lambda_n = 0.8;
Lambda = [lambda_s lambda_n];
numspeechexemplars = 5000;
numiter = 100;
updateH = 1;
computecost = 1;

[activations,H,cost] = NMDwithReverb(sub_Z, A, L, Lambda, numspeechexemplars, numiter, updateH, computecost)
