ftoread = 'speech_dict_2570_all.csv';
S = csvread(ftoread);

ftoread = 'noise_dict_2570_all.csv';
N = csvread(ftoread);

L = 10;
lambda_s = 1.6;
lambda_n = 0.8;
Lambda = [lambda_s lambda_n];
numspeechexemplars = 4000;
numiter = 100;
updateH = 0;
computecost = 1;

genders = {"f10", "m10"}
envs = {"ipad_office1", "ipad_balcony1", "ipad_confroom1", "ipad_confroom2", "ipad_bedroom1", "ipad_livingroom1", "ipad_office2", "ipadflat_confroom1", "ipadflat_office1", "iphone_balcony1", "iphone_bedroom1", "iphone_livingroom1"}

for j =1:3
    gender=genders{j}
    for i =1:13
        env = envs{i}

        ftoread = strcat("./noise_dicts/noise_dict_2570_wiener_denoised_", gender, "_script5_", env, ".csv");
        AN = csvread(ftoread);

        ftoread = strcat("./test_dicts/test_dict_257_wiener_denoised_", gender, "_script5_", env, ".csv");
        Z = csvread(ftoread);
        sub_Z = Z(:, 1:100);

        A = [S N AN];
        size(A)

        [activations,H,cost] = NMDwithReverb(sub_Z, A, L, Lambda, numspeechexemplars, numiter, updateH, computecost);
        csvwrite(strcat("./activations/activations_wiener_denoised_", gender, "_script5_", env, ".csv"), activations);
    end
end
