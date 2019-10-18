ftoread = 'speech_dict_2570.csv';
S = csvread(ftoread);

ftoread = 'noise_dict_2570.csv';
N = csvread(ftoread);

L = 10;
lambda_s = 1.6;
lambda_n = 0.8;
Lambda = [lambda_s lambda_n];
numspeechexemplars = 5000;
numiter = 100;
updateH = 1;
computecost = 1;

envs = {'ipad_office1', 'ipad_balcony1', 'ipad_confroom1', 'ipad_confroom2', 'ipad_bedroom1', 
        'ipad_livingroom1', 'ipad_office2', 'ipadflat_confroom1', 'ipadflat_office1', 'iphone_balcony1', 
        'iphone_bedroom1', 'iphone_livingroom1'}

for i =1:13
    env = envs{i}
    ftoread = './noise_dict/noise_dict_1000_'+env+'.csv';
    AN = csvread(ftoread);

    ftoread = './test_dict/test_dict_2570_f10_script5_'+env+'.csv';
    Z = csvread(ftoread);
    sub_Z = Z(:, 10:110);

    A = [S N AN];
    size(A)

    [activations,H,cost] = NMDwithReverb(sub_Z, A, L, Lambda, numspeechexemplars, numiter, updateH, computecost);
    csvwrite("test_rir_f10_ipad_office1.csv", H);
end
