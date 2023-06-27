

%% setup
% add datapath
addpath('h:/gitdata/uscropsoil/'); % the data path 
basemap   = '2022_us48_county.nc'; % the spatial units
years     = [2008:2022];           % the years of National CDLs


cdlfiles  = []; % a list of CDLs
for yi = 1:length(years)
    year = num2str(years(yi));
    cdlfiles = [cdlfiles {strcat(year,'_30m_cdls.nc')}];
end

soilmap   = 'MapunitRaster_30m.nc'; % the gSSURGO file
soilvar = 'MapunitRaster_30m'; % soil variable in soilmap

outfile   = 'fipssoilcdl.csv';  %output filename

basevar       = 'fips'; % the spatial variable name in basemap
basemissing   = 65535;  % the missing value in basemap

basenrow      = ncinfo(basemap,basevar).Size(2);
basencol      = ncinfo(basemap,basevar).Size(1);

nchunk        = 400; % the no. of bands to cover the lower 48 states
nchunkcol     = ceil(basencol/nchunk); % the no of columns in each band

% read latitude and longitude info
basex  = ncread(basemap,'x'); % the longitude center values west to east
basey  = ncread(basemap,'y'); % the latitude center values (north to south)
soilx  = ncread(soilmap,'x');  % the longitude center values (west to east)
soily  = ncread(soilmap,'y');  % the latitude center values (north to south)

for ci = 1:nchunk
    fprintf('Working on the %d th out of %d chunks\n',ci,nchunk);

    tic;
    colstart = (ci-1)*nchunkcol+1;
    colcount = (ci==nchunk)*(basencol - (nchunk-1)*nchunkcol)+(ci<nchunk)*nchunkcol;
    % chunk from basemap
    basedata  = ncread(basemap,basevar,[colstart 1],[colcount Inf]);
    basetable = array2table(reshape(basedata,[size(basedata,1)*size(basedata,2) 1]),'VariableNames',{basevar});
    basetable.y = repmat(basey,[colcount 1]);
    basetable.x = reshape(repmat([basex(colstart:(colstart+colcount-1))'],[length(basey) 1]),[size(basedata,1)*size(basedata,2) 1]);
    fprintf('    Loading BaseMap: %6.2f seconds\n', toc);

    tic;
    soilcolstart = find(abs(soilx-min(basetable.x))==min(abs(soilx-min(basetable.x))));
    soilcolend   = find(abs(soilx-max(basetable.x))==min(abs(soilx-max(basetable.x))));
    soilcolcount = soilcolend - soilcolstart +1;


    soildata = ncread(soilmap,soilvar,[soilcolstart 1],[soilcolcount Inf]);
    soiltable = array2table(reshape(soildata,[size(soildata,1)*size(soildata,2) 1]),'VariableNames',{'soil'});
    soiltable.y = repmat(soily,[soilcolcount 1]);
    soiltable.x = reshape(repmat([soilx(soilcolstart:(soilcolstart+soilcolcount-1))'],[length(soily) 1]), ...
        [size(soildata,1)*size(soildata,2) 1]);


    minx = max(min(soiltable.x),min(basetable.x));
    maxx = min(max(soiltable.x),max(basetable.x));
    miny = max(min(soiltable.y),min(basetable.y));
    maxy = min(max(soiltable.y),max(basetable.y));

    basetable.soil = zeros(size(basetable,1),1);

    temp = soiltable(soiltable.x>=minx&soiltable.x<=maxx&soiltable.y>=miny&soiltable.y<=maxy,"soil");
    basetable.soil(basetable.x>=minx&basetable.x<=maxx&basetable.y>=miny&basetable.y<=maxy) = temp.soil;

    basetable.area = 900*ones(size(basetable,1),1)/4046.86; % cell area in acres 
    basetable.fips = double(basetable.fips);
    fprintf('    Loading Soilmap: %6.2f seconds\n', toc);

    % chunk from cdl
    for yi = 1:length(years)
        tic;
        year = years(yi);
        cdlx = ncread(char(cdlfiles(yi )),'x');
        cdly = ncread(char(cdlfiles(yi)),'y');

        cdlcolstart = find(abs(cdlx-min(basetable.x))==min(abs(cdlx-min(basetable.x))));
        cdlcolend   = find(abs(cdlx-max(basetable.x))==min(abs(cdlx-max(basetable.x))));
        cdlcolcount = cdlcolend - cdlcolstart +1;


        cdldata = ncread(char(cdlfiles(yi)),'crop',[cdlcolstart 1],[cdlcolcount Inf]);
        cdltable = array2table(reshape(cdldata,[size(cdldata,1)*size(cdldata,2) 1]),'VariableNames',{'crop'});
        cdltable.y = repmat(cdly,[cdlcolcount 1]);
        cdltable.x = reshape(repmat([cdlx(cdlcolstart:(cdlcolstart+cdlcolcount-1))'],[length(cdly) 1]), ...
            [size(cdldata,1)*size(cdldata,2) 1]);


        minx = max(min(cdltable.x),min(basetable.x));
        maxx = min(max(cdltable.x),max(basetable.x));
        miny = max(min(cdltable.y),min(basetable.y));
        maxy = min(max(cdltable.y),max(basetable.y));

        basetable.crop = zeros(size(basetable,1),1);

        temp = cdltable(cdltable.x>=minx&cdltable.x<=maxx&cdltable.y>=miny&cdltable.y<=maxy,"crop");
        basetable.crop(basetable.x>=minx&basetable.x<=maxx&basetable.y>=miny&basetable.y<=maxy) = temp.crop;
        



        % since all the raster files are aligned with each other, the merge
        % function is slower than the extraction based on index. 
        % tic;
        % basetable = outerjoin(basetable,cdltable,'Keys',{'x','y'},MergeKeys=true,Type='left');
        % toc;

        basetable.Properties.VariableNames('crop') = {strcat('crop',num2str(year))};
        fprintf('    Loading %d CDL takes %6.2f seconds\n',year, toc);

        clear temp cdltable;
    end

    tmp = basetable(basetable.fips~=65535,:);

    tic;
    % aggregate and save as temp table
    for yi = 1:length(years)
        year = years(yi);

        [B,~,gi] = unique(tmp{:,[1 4 (5+yi)]},'rows','stable'); % unique rows, with grouping index
        B(:,4) = accumarray(gi(:), tmp{:,5}, [], @sum);
        temptable = array2table(B,'VariableNames',{'fips','soil','crop','area'});
        temptable.year = year*ones(size(B,1),1);



        % the varfun is slower than index based accumarray (roughly 2 times
        % slower) 
        % tic;
        % temptable = varfun(@sum,tmp,"InputVariables",{'area'}, ...
        %                     "GroupingVariables",{'fips','soil',strcat('crop',num2str(year))});
        % toc;
        if (yi==1)
            clear result
            result = temptable;
        else
            result = [result;temptable];
        end
    end
    fprintf('    The tabulation takes %6.2f seconds\n',toc);

    clear soildata soiltable
    clear basetable basedata
    clear cdldata
    clear tmp
    % save into a csv 
    if (ci == 1)
        writetable(result,outfile,'WriteMode','overwrite');
    else
        writetable(result,outfile,'WriteMode','append');
    end

end




















