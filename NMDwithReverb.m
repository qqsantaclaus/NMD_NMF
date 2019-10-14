function [activations,H,cost] = NMDwithReverb(Z, A, L, Lambda, numspeechexemplars, numiter, updateH, computecost)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% If you use this code please cite
% [1] Deepak Baby and Hugo Van hamme. Supervised Speech Dereverberation in 
% Noisy Environments using Exemplar-based Sparse Representations. 
% In Acoustics, Speech and Signal Processing (ICASSP), 2016 IEEE 
% International Conference on, Shanghai, China, March 2016. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code to estimate the activations and RIR using the NMD-based formulation
% in the paper.
%
% Inputs:
%   Z : input data matrix (reverberated)
%   A : Dictionary Matrix ; contains speech and noise dictionaries A=[S N]
%   L : length of the RIR to be estimated
%   Lambda : sparsity penalty for speech and noise  ; Lambda = [lambda_s lambda_n]
%   numspeechexemplars : number of speech exemplars
%   numiter : number of iterations
%   updateH : Is RIR to be estimated ? updateH=0 yields the traditional NMD activations
%   computecost : should the cost after every iteration be computed ?
%
% Outputs :
%   activations : output activations for exemplars
%   H : DFT of the RIR model
%   cost : cost after every iteration (for checking convergence)
%
% Written By Deepak Baby, KU Leuven, September 2015.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

usegpu = 0; % should a GPU be used ? set it to 0 if GPU is not available

if lt(nargin,8)
    computecost=0;
end

if lt(nargin,7)
    updateH=0;
end

[B,F] = size(Z);
[D,nEx] = size(A);
T = D/B;

Lambda = [Lambda(1,1)*ones(numspeechexemplars,1); Lambda(1,2)*ones(nEx-numspeechexemplars,1)];

if usegpu
    epsilon = gpuArray(single( 1e-20));
    Z = gpuArray(single(Z));
    A = gpuArray(single(A));
    A = max(A,epsilon);
    Lambda = gpuArray(single(Lambda));
    Lambda = max(Lambda,epsilon);
else
    epsilon = 1e-20;
    A = max(A,epsilon);
end

Lambdabig = repmat(Lambda,1, F);

if ~updateH
    H = ones(size(Z,1),1);
    L=1;% if H is not to be updated, initialise it as an impulse (no reverberation)
end

% Initialisations
activations = ones(size(A,2), size(Z,2));
if updateH
    rng(333);
    H = rand(size(Z,1), L);
    H = constrainH(H);
end

activations = gpuArray(single(activations));
H = gpuArray(single(H));


S = A(:,1:numspeechexemplars); % speech dictionary
N = A(:,numspeechexemplars+1:end); % noise dictionary

if usegpu
    cost = gpuArray.zeros(1,numiter);
else
    cost = zeros(1,numiter);
end

%%%%%%% BEGIN ITERATIVE UPDATES
for iter = 1 : numiter
    %iter
    
    Z_tilde = reconZ_speechandnoise(A,activations,numspeechexemplars, H);
    ratio = (max(Z,epsilon))./(max(Z_tilde,epsilon)); % ratio R in the paper
    
    if computecost
        cost(iter) = sum(sum((Z.*log(ratio)) - Z + Z_tilde)) + sum(sum((Lambdabig.*activations))) ;
    end
    %%%%% updates for activations
    % for speech activations
    fnmultiplyH = @(tt) bsxfun(@times, [ratio(:,tt:end) gpuArray.zeros(B,tt-1)], H(:,tt)); % finding H and R product
    HmultipliedwithRatios = arrayfun(fnmultiplyH, 1:L, 'UniformOutput', false); % yields a 3d struct of size BxFxL
    HmultipliedwithRatios = cat(3,HmultipliedwithRatios{:}); % converting cell to mat at concatenating along the 3rd dimension (size BxFxL as above, but in matrix format)
    fnmultiplywithS = @(kk) pagefun(@mtimes, S((kk-1)*B+1: kk*B,:)', [HmultipliedwithRatios(:,kk:end,:) gpuArray.zeros(B,kk-1,L)]); % multiply with transpose of S_t
    HRwithS = arrayfun(fnmultiplywithS, 1:T, 'UniformOutput', false); % results in a NxFxLxT where N is the number of exemplars in S (is cell struct format)
    clear HmultipliedwithRatios
    HRwithS =cat(4,HRwithS{:});
    HRwithSnumer = sum(sum(HRwithS,4),3); % convert it into mat format and add the 3rd and 4th dimensions to get a matrix of size NxF
    clear HRwithS
    
    if usegpu
        dummyones = gpuArray.ones(size(ratio));
    else
        dummyones = ones(size(ratio));
    end
    fnmultiplyH1 = @(tt) bsxfun(@times, [dummyones(:,tt:end) gpuArray.zeros(B,tt-1)], H(:,tt));
    HmultipliedwithRatios1 = arrayfun(fnmultiplyH1, 1:L, 'UniformOutput', false); % yields a 3d struct of size BxFxL
    HmultipliedwithRatios1 = cat(3,HmultipliedwithRatios1{:}); % converting cell to mat at concatenating along the 3rd dimension (size BxFxL as above, but in matrix format)
    fnmultiplywithS1 = @(kk) pagefun(@mtimes, S((kk-1)*B+1: kk*B,:)', [HmultipliedwithRatios1(:,kk:end,:) gpuArray.zeros(B,kk-1,L)]);
    HRwithS1 = arrayfun(fnmultiplywithS1, 1:T, 'UniformOutput', false); % results in a NxFxLxT where N is the number of exemplars in S (is cell struct format)
    clear HmultipliedwithRatios1
    HRwithS1 =cat(4,HRwithS1{:});
    HRwithSdenom = sum(sum(HRwithS1,4),3); % convert it into mat format and add the 3rd and 4th dimensions to get a matrix of size NxF
    clear HRwithS1
    
    % for noise activations  ; uses the normal NMF updates
    fnmultiplynumerN = @(kk) N((kk-1)*B+1: kk*B,:)'* [ratio(:,kk:end) gpuArray.zeros(B,kk-1)];
    numersN = arrayfun(fnmultiplynumerN, 1:T, 'UniformOutput', false);
    numersN = sum(cat(3,numersN{:}),3);
    
    fnmultiplydenomN = @(k) N((k-1)*B+1: k*B,:)'* [dummyones(:,k:end) gpuArray.zeros(B,k-1)];
    denomsN = arrayfun(fnmultiplydenomN, 1:T, 'UniformOutput', false);
    denomsN = sum(cat(3,denomsN{:}),3);
    
    numers = [HRwithSnumer ; numersN];
    denoms = [HRwithSdenom; denomsN];
    weightX = max(numers,epsilon)./(max(denoms,epsilon)+Lambdabig);
    
    
    activations = activations.* weightX;
    clear HRwithSnumer numersN numers denoms HRwithSdenom denomsN ratio  Y_tilde_speech Z_tilde weightX
    %        figure, imagesc(log(activations+1e-30)), colormap jet, pause
    
    %%%%%%%%%%%%%%% updates for RIR
    if updateH
        Y_tilde_speech = reconNMD(S,activations(1:numspeechexemplars,:),T);
        Z_tilde= reconZ_speechandnoise(A,activations,numspeechexemplars,H);
        ratio = max(Z,epsilon)./max(Z_tilde,epsilon);
        
        % Multiplicative updates for H
        fnHnumer = @(kk) sum((ratio.*[zeros(B,kk-1) Y_tilde_speech(:,1:end-kk+1)]),2);
        numerH = arrayfun(fnHnumer, 1:L, 'UniformOutput', false);
        numerH = cat(2,numerH{:});
        
        fnHdenom = @(kkl) sum(Y_tilde_speech(:,1:end-kkl+1),2); % make shifted versions of Y_tilde
        denomH = arrayfun(fnHdenom, 1:L, 'UniformOutput', false);
        denomH = cat(2,denomH{:});
        
        weightH = max(numerH,epsilon)./max(denomH,epsilon);
        
        H = H.* weightH ;
        H = constrainH(H); % apply constraints on H
        
        clear ratio  Y_tilde_speech Z_tilde denomH numerH weightH
        
    end % updateH
end % iterations

end % EOF

function Z_tilde = reconZ_speechandnoise(A,X,numspeechexemplars, H)

% To reconstruct Z from A, X and H using the NMD + reverb formulation
T = size(A,1)/size(H,1);

Y_tilde_speech = reconNMD(A(:,1:numspeechexemplars),X(1:numspeechexemplars,:),T);
Z_tilde_speech = applyH(Y_tilde_speech,H); % RIR is applied only on the speech estimate
Z_tilde_noise = reconNMD(A(:,numspeechexemplars + 1:end),X(numspeechexemplars + 1: end,:),T);

Z_tilde = Z_tilde_speech + Z_tilde_noise ;
end

function Z = applyH(Y,H)

% To reconstruct the reverberated spectrogram Z from non-reverberated spectrogram Y with RIR weights in H using the reverb formulation

[B,L] = size(H);

fnrir = @(tau) bsxfun(@times, [zeros(B,tau-1) Y(:,1:end-tau+1)], H(:,tau));
Z = arrayfun(fnrir, 1:L, 'UniformOutput', false); Z = cat(3, Z{:});
Z = sum(Z,3);
end

function Y_tilde_speech = reconNMD(A,X,T)

% To reconstruct Z from A, and X using the NMD formulation

[D,nEx] = size(A);
B = D/T;

fnnmd = @(t) A((t-1)*B+1:t*B,:)*[zeros(nEx,t-1) X(:,1:end-t+1)];
Y_tilde_speech = arrayfun(fnnmd, 1:T, 'UniformOutput', false); Y_tilde_speech = cat(3, Y_tilde_speech{:});
Y_tilde_speech = sum(Y_tilde_speech,3);

end

function H = constrainH(H)

% TO constrain the RIR H to have realistic properties

H = max(H,1e-20);
H = bsxfun(@rdivide, H, H(:,1));

% % clamp H to have decaying weights 
for cl = 2:size(H,2)
    H(:,cl) = min(H(:,cl), H(:,cl-1));
end

% normalise rows for additive bound
H = bsxfun(@rdivide, H, sum(H,2));

end
