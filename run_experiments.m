ftoread = 'speech_dict_2570.csv';
S = csvread(ftoread);

ftoread = 'noise_dict_2570.csv';
N = csvread(ftoread);

ftoread = 'test_dict_2570.csv';
Z = csvread(ftoread);

A = [S N];
L = 10;
lambda_s = 1.6;
lambda_n = 0.8;
Lambda = [lambda_s lambda_n];
numspeechexemplars = 4500;
numiter = 100;
updateH = 1;
computecost = 1;

[activations,H,cost] = NMDwithReverb(Z, A, L, Lambda, numspeechexemplars, numiter, updateH, computecost)