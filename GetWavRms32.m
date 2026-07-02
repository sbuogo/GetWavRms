% GetWavRms - Compute rms values in gated sliding time windows for
%   waveform contained in WAV file.
% Interactive version: input start-stop time of ping series for a
% single frequency, and gate start-stop time within each ping.
% Select first ping in a series, cross-correlate with series and find
% peaks, align & overlap pings, compute rms in selected gate, average.
% Peaks lower than given min. relative height are skipped.
% May process two WAV files, one for H and one for Ref, using same
% global gate parameters. Display rms vaules and H/Ref ratio.
% Add command & display log to file ('diary'), including date/time.
% May reuse H file with different Ref.
%
% REVISION HISTORY:
% v. 1.0 2024-05-27 First version, manually enter start-stop time,
%                   interactively set min. peak distance.
%    1.1 2024-05-28 Add optional highpass, S-G filter
%    1.2 2024-05-30 Read entire waveform at once, then take subarrays
%    1.3 2024-06-10 Optional highpass/bandpass
%    2.0 2024-06-11 Process H and Ref files together, display H/Ref ratio
%    2.1 2024-06-21 Add 'diary' command log to file
%    2.2 2024-09-20 Add option for single H file or two [H,Ref] files,
%                   input for options now clearer.
%    2.3 2024-12-12 Fixed non-integer sample step with small time step.
%    3.0 2025-04-08 Use autocorrelation to select pings, get rms on each.
%                   Removed fitering, no longer necessary.
%    3.1 2026-06-03 Process H and Ref files separately to handle different 
%                   sample rates. Restored optional filtering.
%    3.2 2026-07-02 Fixed minor bugs, added GNU GPL license.
% 
% Copyright (C) 2026  Silvano Buogo  -  <silvano.buogo@cnr.it>
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details, available at:
% <https://www.gnu.org/licenses/>

clf

scriptVers = "GetWavRms 3.2";
logFile = 'GetWavRmsLog.txt';

diary off
sameHFile = false;
chgRefFile = false;
isthereRefFile = false; % default is only H file

figH   = figure(1); set(gcf,'Name','H');

if input('\nWAV files to read (1 = only H; 2 = H and Ref) >> ') == 2
    isthereRefFile = true;
    figRef = figure(2); set(gcf,'Name','Ref');
end

startFolder = uigetdir(pwd,'Select start directory');
[HFileName,HPath] = uigetfile({'*.wav';'*.WAV'}, ...
    'Select H wav file', startFolder); 
if isthereRefFile
    [RefFileName,RefPath] = uigetfile({'*.wav';'*.WAV'}, ...
        'Select REF wav file', startFolder); 
    if ~ischar(RefFileName)
        disp('* User canceled - Exiting.'); return
    end
end
if ~ischar(HFileName) 
    disp('* User canceled - Exiting.'); return
else
    HFile = [HPath HFileName];
    if isthereRefFile
        RefFile = [RefPath RefFileName];
    end
end

diary(fullfile(startFolder,logFile))
fprintf('\n=========== %s - Start: %s\n', scriptVers, datetime('now'))
fprintf('Logging to folder %s\n',startFolder)

HFileInfo = audioinfo(HFile);
smpRateH   =   HFileInfo.SampleRate;
nTotSmpH   =   HFileInfo.TotalSamples;
fileDurH   =   HFileInfo.Duration;

if nTotSmpH > 0
    fprintf('\nH: %s: Rate = %g kHz;  %.3f Msmp;  Dur = %g s\n',...
        HFileName, smpRateH/1e3, nTotSmpH/1e6, fileDurH);
else
    disp('* Warning: H wav file seems to be void.')
    return
end

if isthereRefFile
    RefFileInfo = audioinfo(RefFile);
    smpRateRef = RefFileInfo.SampleRate;
    nTotSmpRef = RefFileInfo.TotalSamples;
    fileDurRef = RefFileInfo.Duration;

    if nTotSmpRef > 0
        fprintf('Ref: %s: Rate = %g kHz;  %.3f Msmp;  Dur = %g s\n',...
            RefFileName, smpRateRef/1e3, nTotSmpRef/1e6, fileDurRef);
    else
        disp('* Warning: Ref wav file seems to be void.')
        return
    end
end

firstIteration = true;
while 1 %%%%%%%% main loop for selected WAV file, repeat until user break
    if sameHFile
        fprintf('Using same H file %s\n', HFileName);
    end
    if isthereRefFile
        if chgRefFile        % repeat with different Ref file
            [RefFileName,RefPath] = uigetfile({'*.wav';'*.WAV'}, ...
                        'Select REF wav file', startFolder); 
            if ~ischar(RefFileName)
                disp('* User canceled - Exiting.'); return
            end
            
            RefFile = [RefPath RefFileName];
            RefFileInfo = audioinfo(RefFile);  
            smpRateRef = RefFileInfo.SampleRate;
            nTotSmpRef = RefFileInfo.TotalSamples;
            fileDurRef = RefFileInfo.Duration;
            fprintf('Ref: %s: Rate = %g kHz;  %.3f Msmp;  Dur = %g s\n',...
               RefFileName, smpRateRef/1e3, nTotSmpRef/1e6, fileDurRef);
        else
            if firstIteration == true
                % do not print Ref file again
            else
                fprintf('Using same Ref file %s\n', RefFileName);
            end
        end
    end
    firstIteration = false;

    startTimeH = input('\nH start time in s: ');
    stopTimeH  = input('H stop time in s: ');
    if stopTimeH > fileDurH
        disp('Warning: H stop time exceeding file duration.')
        continue
    end
    
    startSmpH = 1 + int32(startTimeH*smpRateH);
    stopSmpH = int32(stopTimeH*smpRateH);
    [origWfmH,smpRateH] = audioread(HFile,double([startSmpH stopSmpH]));
    figure(figH)
    plot(origWfmH)
    if input('Enter 1 to change H start/stop, 0 to proceed >> ') == 1
        continue    % go to next main loop iteration
    end
    pkFH   = medfreq(origWfmH,  smpRateH); % peak f 

    if isthereRefFile
        startTimeRef = input('Ref start time in s: ');
        stopTimeRef  = input('Ref stop time in s: ');
        if stopTimeRef > fileDurRef
            disp('Warning: Ref stop time exceeding file duration.')
            continue
        end

        startSmpRef = 1 + int32(startTimeRef*smpRateRef);
        stopSmpRef = int32(stopTimeRef*smpRateRef);  
        [origWfmRef,smpRateRef] = audioread(RefFile, ...
                                    double([startSmpRef stopSmpRef]));
        figure(figRef)
        plot(origWfmRef)
        if input('Enter 1 to change Ref start/stop, 0 to proceed >> ')==1
            continue    % next loop
        end
        pkFRef = medfreq(origWfmRef,smpRateRef);
    else
        pkFRef = 0;
    end

    fprintf('>>> Peak frequency/Hz: H = %.3f, Ref = %.3f\n',pkFH,pkFRef); 

    filtWfmH = origWfmH; % initialize waveform to unfiltered
    if isthereRefFile
        filtWfmRef = origWfmRef; % initialize
    end

    while 1 % highpass-lowpass filter, choose cut f 
        hiPassF = input('Highpass filter cut in Hz (0 = no filter): ');
        if hiPassF == 0
            break
        else
            loPassF = input('Lowpass filter cut in Hz (0 = no filter): ');
            disp('Filtering ...')
            if loPassF == 0
                filtWfmH   = highpass(origWfmH,  hiPassF,smpRateH);
                if isthereRefFile
                    filtWfmRef = highpass(origWfmRef,hiPassF,smpRateRef);
                end
            else
                filtWfmH = bandpass(origWfmH,[hiPassF loPassF],smpRateH);
                if isthereRefFile
                    filtWfmRef=bandpass(origWfmRef,[hiPassF loPassF], ...
                                                       smpRateRef);
                end
            end
            figure(1)
            plot(filtWfmH)
            if isthereRefFile
                figure(2)
                plot(filtWfmRef)
            end
            fprintf('>>> Current filter: [%.1f - %.1f] Hz\n', ...
                                                hiPassF,loPassF);
            pkFH = medfreq(filtWfmH,smpRateH); % update pk freq.
            if isthereRefFile
                pkFRef = medfreq(filtWfmRef,smpRateRef);
            end
            fprintf('    New peak f/Hz: H = %.3f, Ref = %.3f\n',...
                    pkFH,pkFRef); 
            if input('Enter 1 to change, 0 to proceed >> ') == 0
                break % filter ok
            end
        end
    end % filter

    %%%%%%%%%%%%%%  NEW since v. 3.0
    while 1 % select ping
        pingStart = input('H ping start time in s: '); % first ping
        pingStop  = input('H ping stop time in s: '); % first ping
        startSmpHPing = 1 + int32(pingStart*smpRateH - startSmpH);
        stopSmpHPing  = int32(pingStop*smpRateH - startSmpH);
        if startSmpHPing <= 0 || stopSmpHPing <= 0
            fprintf('*** Invalid time - repeat:\n')
            continue
        end
        figure(figH)
        plot(filtWfmH(startSmpHPing:stopSmpHPing))
        if input('Enter 1 to change ping start/stop, 0 to proceed >> ')==0
            break % exit loop
        end
    end 
    pingWfmH = filtWfmH(startSmpHPing:stopSmpHPing);

    xcorrH = xcorr(pingWfmH,filtWfmH);
    figure(figH); plot(xcorrH)

    if isthereRefFile %%% repeat above for Ref file
        while 1 % select ping
            pingStart = input('Ref ping start time in s: '); % first ping
            pingStop  = input('Ref ping stop time in s: '); % first ping
            startSmpRefPing = 1 + int32(pingStart*smpRateRef-startSmpRef);
            stopSmpRefPing  = int32(pingStop*smpRateRef - startSmpRef);
            if startSmpRefPing <= 0 || stopSmpRefPing <= 0
                fprintf('*** Invalid time - repeat:\n')
                continue
            end
            figure(figRef)
            plot(filtWfmRef(startSmpRefPing:stopSmpRefPing))
        if input('Enter 1 to change ping start/stop, 0 to proceed >> ')==0
                break % exit loop
            end
        end 
        pingWfmRef = filtWfmRef(startSmpRefPing:stopSmpRefPing);

        xcorrRef = xcorr(pingWfmRef,filtWfmRef);
        figure(figRef); plot(xcorrRef)
    end % if Ref file active

    while 1 % xcorr peak detect
        % note: findpeaks() used twice, first with no output arg.s to put
        % marks on figures, then using output arg.s to save current peaks
        minPkTdist=input('Min. peak distance in ms: ');
        minPkRelHght=input('Min. peak relative height in %: ')/100;
        minPkDistH   = 1e-3 * minPkTdist * smpRateH;

        figure(figH); findpeaks(xcorrH, ...
            "MinPeakHeight",max(xcorrH)*minPkRelHght, ...
            "MinPeakDistance",minPkDistH ); 

        if isthereRefFile
            minPkDistRef = 1e-3 * minPkTdist * smpRateRef;
            figure(figRef); findpeaks(xcorrRef, ...
                "MinPeakHeight",max(xcorrRef)*minPkRelHght, ...
                "MinPeakDistance",minPkDistRef ); 
        end

        if input('Enter 1 to change peaks, 0 to proceed >> ') == 0
            break % keep current peaks
        end
    end % xcorr peak

    [~,pkXcorrH] = findpeaks(xcorrH, ...
            "MinPeakHeight",max(xcorrH)*minPkRelHght, ...
            "MinPeakDistance",minPkDistH );
    smpOffsH   = pkXcorrH   - pkXcorrH(1);

    if isthereRefFile
        [~,pkXcorrRef] = findpeaks(xcorrRef, ...
                "MinPeakHeight",max(xcorrRef)*minPkRelHght, ...
                "MinPeakDistance",minPkDistRef );
        smpOffsRef = pkXcorrRef - pkXcorrRef(1);
    end

    %%%%%%%%% overlay repeated pings found with xcorr
    % note: last one may fall beyond array length
    figure(figH);
    for idx = 1 : length(pkXcorrH)
        if (stopSmpHPing+smpOffsH(idx) < length(filtWfmH))
            plot(filtWfmH(startSmpHPing+smpOffsH(idx) : ...
                       stopSmpHPing+smpOffsH(idx) ))
        end
        hold on
    end
    hold off

    while 1 % select X axis limits to identify gate
        xlimhi = input('H: X axis low limit: ');
        xlimlo = input('H: X axis high limit: ');
        xlim([xlimhi xlimlo])
        if input('Enter 1 to change X limits, 0 to proceed >> ') == 0
            break % keep current X axis
        end
    end

    while 1 % select H gate for rms
        gateStartH = input('H: gate start sample: ');
        gateStopH  = input('H: gate stop sample: ');
        gateAreaX = [gateStartH gateStopH gateStopH gateStartH];
        gateMax = max(filtWfmH(startSmpHPing:stopSmpHPing));
        gateMin = min(filtWfmH(startSmpHPing:stopSmpHPing));
        gateAreaY = [gateMin gateMin gateMax gateMax];
        patch(gateAreaX,gateAreaY,'green', ...
            'FaceAlpha',0.1) % highlight gate area (transparent)
        if input('Enter 1 to change gate, 0 to proceed >> ') == 0
            break % keep current X axis
        end
        delete(findobj('type', 'patch')); % erase current area
    end

    if isthereRefFile % repeat above
        figure(figRef);
        for idx = 1 : length(pkXcorrRef)
            if (stopSmpRefPing+smpOffsRef(idx) < length(filtWfmRef))
                plot(filtWfmRef(startSmpRefPing+smpOffsRef(idx) : ...
                            stopSmpRefPing+smpOffsRef(idx) ))
            end
            hold on
        end
        hold off
    
        while 1 % select X axis limits to identify gate
            xlimhi = input('Ref: X axis low limit: ');
            xlimlo = input('Ref: X axis high limit: ');
            xlim([xlimhi xlimlo])
            if input('Enter 1 to change X limits, 0 to proceed >> ') == 0
                break % keep current X axis
            end
        end
    
        while 1 % select Ref gate for rms
            gateStartRef = input('Ref: gate start sample: ');
            gateStopRef  = input('Ref: gate stop sample: ');
            gateAreaX=[gateStartRef gateStopRef gateStopRef gateStartRef];
            gateMax = max(filtWfmRef(startSmpRefPing:stopSmpRefPing));
            gateMin = min(filtWfmRef(startSmpRefPing:stopSmpRefPing));
            gateAreaY = [gateMin gateMin gateMax gateMax];
            patch(gateAreaX,gateAreaY,'green', ...
                'FaceAlpha',0.1) % highlight gate area (transparent)
            if input('Enter 1 to change gate, 0 to proceed >> ') == 0
                break % keep current X axis
            end
            delete(findobj('type', 'patch')); % erase current area
        end

    end % if Ref file

    gateRmsH = zeros(1,length(pkXcorrH)); % initialize rms vectors

    for idx = 1 : length(pkXcorrH) %%%%%%%%%%%% get gate rms
                % note: last gate may fall beyond array length
        startSmp = startSmpHPing + smpOffsH(idx) + gateStartH;
        stopSmp  = startSmpHPing + smpOffsH(idx) + gateStopH;
        if stopSmp < length(filtWfmH)
            gateRmsH(idx) = rms(filtWfmH(startSmp:stopSmp));
        end
    end
    if isthereRefFile
        gateRmsRef = zeros(1,length(pkXcorrRef));

        for idx = 1 : length(pkXcorrRef) % same for Ref
           startSmp = startSmpRefPing + smpOffsRef(idx) + gateStartRef;
           stopSmp  = startSmpRefPing + smpOffsRef(idx) + gateStopRef;
           if stopSmp < length(filtWfmRef)
               gateRmsRef(idx) = rms(filtWfmRef(startSmp:stopSmp));
           end
        end
    end

    figure(figH); plot(gateRmsH,'o-')
    legend('rms(H)')
    xlabel('ping number')
    fprintf('>>> Mean rms(H) = %.3e (%.0f Hz)\n', mean(gateRmsH), pkFH)
    if isthereRefFile
        figure(figRef); plot(gateRmsRef,'o-')
        legend('rms(Ref)')
    fprintf('>>> Mean rms(Ref) = %.3e (%.0f Hz), mean H/Ref = %.3f\n', ...
            mean(gateRmsRef),pkFRef,mean(gateRmsH)/mean(gateRmsRef) )
        xlabel('ping number')
   end

   nextRun = ...
     input('\nNext: 1 = same H, new Ref, 2 = same H & Ref, 0 = exit: ');
   switch nextRun
        case 1
            chgRefFile = true;
        case 2
            chgRefFile = false;
        otherwise
            break % exit main loop
   end
   sameHFile = true; % repeat main loop on same H
end

fprintf('\n=========== %s - End: %s\n', scriptVers, datetime('now'))
diary off
disp('Normal exit.')
return
