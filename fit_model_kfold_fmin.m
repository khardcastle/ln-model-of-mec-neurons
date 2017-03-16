function [testFit,trainFit,param_mean] = fit_model_kfold_fmin(A,dt,spiketrain,filter,modelType)

%%%% WITH 5-FOLD CROSS VALIDATION %%%%%
[~,numCol] = size(A);
repeat = 10;
sections = repeat*5;

% divide the data up into 5*repeat pieces
edges = round(linspace(1,numel(spiketrain)+1,sections+1));

% initialize matrices
testFit = nan(repeat,6); % var ex, correlation, llh increase, mse, # of spikes, length of test data
trainFit = nan(repeat,6); % var ex, correlation, llh increase, mse, # of spikes, length of test data
paramMat = nan(repeat,numCol);

for k = 1:repeat
    
    % get test data from edges - each test data chunk comes from entire session
    test_ind  = [edges(k):edges(k+1)-1 edges(k+repeat):edges(k+repeat+1)-1 ...
        edges(k+2*repeat):edges(k+2*repeat+1)-1 edges(k+3*repeat):edges(k+3*repeat+1)-1 ...
        edges(k+4*repeat):edges(k+4*repeat+1)-1]   ;
    
    test_spikes = spiketrain(test_ind); %test spiking
    smooth_spikes_test = conv(test_spikes,filter,'same'); %returns vector same size as original
    smooth_fr_test = smooth_spikes_test./dt;
    test_A = A(test_ind,:);
    
    % training data
    train_ind = setdiff(1:numel(spiketrain),test_ind);
    train_spikes = spiketrain(train_ind);
    smooth_spikes_train = conv(train_spikes,filter,'same'); %returns vector same size as original
    smooth_fr_train = smooth_spikes_train./dt;
    train_A = A(train_ind,:);
    
    opts = optimset('Gradobj','on','Hessian','on','Display','off');
    
    data{1} = train_A; data{2} = train_spikes;
    if k == 1
        init_param = 1e-3*randn(numCol, 1);
    else
        init_param = param;
    end
    [param] = fminunc(@(param) poissglm_allModels_fmin(param,data,modelType),init_param,opts);
    
    %%%%%%%%%%%%% TEST DATA %%%%%%%%%%%%%%%%%%%%%%%
    % compute the firing rate
    fr_hat_test = exp(test_A * param)/dt;
    smooth_fr_hat_test = conv(fr_hat_test,filter,'same'); %returns vector same size as original
    
    % compare between test fr and model fr
    sse = sum((smooth_fr_hat_test-smooth_fr_test).^2);
    sst = sum((smooth_fr_test-mean(smooth_fr_test)).^2);
    varExplain_test = 1-(sse/sst);
    
    % compute correlation
    correlation_test = corr(smooth_fr_test,smooth_fr_hat_test,'type','Pearson');
    
    % compute llh increase from "mean firing rate model" - NO SMOOTHING
    r = exp(test_A * param); n = test_spikes; meanFR_test = nanmean(test_spikes); 
    
    log_llh_test_model = nansum(r-n.*log(r)+log(gamma(n+1)))/sum(n); %note: log(gamma(n+1)) will be unstable if n is large (which it isn't here)
    log_llh_test_mean = nansum(meanFR_test-n.*log(meanFR_test)+log(gamma(n+1)))/sum(n);
    log_llh_test = (-log_llh_test_model + log_llh_test_mean);
    
    % compute MSE
    mse_test = nanmean((smooth_fr_hat_test-smooth_fr_test).^2);
    
    % fill in all the relevant values for the test fit cases
    testFit(k,:) = [varExplain_test correlation_test log_llh_test mse_test sum(n) numel(test_ind) ];
    
    %%%%%%%%%%%%% TRAINING DATA %%%%%%%%%%%%%%%%%%%%%%%
    % compute the firing rate
    fr_hat_train = exp(train_A * param)/dt;
    smooth_fr_hat_train = conv(fr_hat_train,filter,'same'); %returns vector same size as original
    
    % compare between test fr and model fr
    sse = sum((smooth_fr_hat_train-smooth_fr_train).^2);
    sst = sum((smooth_fr_train-mean(smooth_fr_train)).^2);
    varExplain_train = 1-(sse/sst);
    
    % compute correlation
    correlation_train = corr(smooth_fr_train,smooth_fr_hat_train,'type','Pearson');
    
    % compute log-likelihood
    r_train = exp(train_A * param); n_train = train_spikes; meanFR_train = nanmean(train_spikes);   
    log_llh_train_model = nansum(r_train-n_train.*log(r_train)+log(gamma(n_train+1)))/sum(n_train);
    log_llh_train_mean = nansum(meanFR_train-n_train.*log(meanFR_train)+log(gamma(n_train+1)))/sum(n_train);
    log_llh_train = (-log_llh_train_model + log_llh_train_mean);
    
    % compute MSE
    mse_train = nanmean((smooth_fr_hat_train-smooth_fr_train).^2);
    
    trainFit(k,:) = [varExplain_train correlation_train log_llh_train mse_train sum(n_train) numel(train_ind)];

    % save the parameters
    paramMat(k,:) = param;

end

param_mean = nanmean(paramMat);



%%% extra code that I have used to plot the firing rate
% plot firing rates for test data set
%{
    % plot the firing rate for the whole snippet
    figure()
    filter = gaussmf(-4:4,[2 0]); filter = filter/sum(filter); %smooth over 100 ms
    fr_test = test_spikes/0.02;
    smooth_fr_test = conv(fr_test,filter,'same');
    plot(smooth_fr_test,'k','linewidth',2)
    axis([-inf inf 0 30])
    box off
    hold on
    fr_hat_test = exp(test_A * param)/dt;
    filter = gaussmf(-4:4,[2 0]); filter = filter/sum(filter); %smooth over 100 ms
    smooth_fr_hat_test = conv(fr_hat_test,filter,'same');
    plot(smooth_fr_hat_test,'r','linewidth',2)
    hold off
    title(log_llh_test)
%}
    

return