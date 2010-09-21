function [dr,info,M_,options_,oo_] = dr11_sparse(dr,task,M_,options_,oo_, jacobia_, hessian)
%function [dr,info,M_,options_,oo_] = dr11_sparse(dr,task,M_,options_,oo_, jacobia_, hessian)

% Copyright (C) 2008-2010 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.
%task
info = 0;
klen = M_.maximum_endo_lag + M_.maximum_endo_lead + 1;
kstate = dr.kstate;
kad = dr.kad;
kae = dr.kae;
nstatic = dr.nstatic;
nfwrd = dr.nfwrd;
npred = dr.npred;
nboth = dr.nboth;
order_var = dr.order_var;
nd = size(kstate,1);
nz = nnz(M_.lead_lag_incidence);

sdyn = M_.endo_nbr - nstatic;
k0 = M_.lead_lag_incidence(M_.maximum_endo_lag+1,order_var);
k1 = M_.lead_lag_incidence(find([1:klen] ~= M_.maximum_endo_lag+1),:);
b = jacobia_(:,k0);

if M_.maximum_endo_lead == 0;  % backward models
    a = jacobia_(:,nonzeros(k1'));
    dr.ghx = zeros(size(a));
    m = 0;
    for i=M_.maximum_endo_lag:-1:1
        k = nonzeros(M_.lead_lag_incidence(i,order_var));
        dr.ghx(:,m+[1:length(k)]) = -b\a(:,k);
        m = m+length(k);
    end
    if M_.exo_nbr & task~=1
        jacobia_
        jacobia_(:,nz+1:end)
        b
        dr.ghu = -b\jacobia_(:,nz+1:end);
        disp(['nz=' int2str(nz) ]);
        dr.ghu
    end
    dr.eigval = eig(transition_matrix(dr,M_));
    dr.rank = 0;
    if any(abs(dr.eigval) > options_.qz_criterium)
        temp = sort(abs(dr.eigval));
        nba = nnz(abs(dr.eigval) > options_.qz_criterium);
        temp = temp(nd-nba+1:nd)-1-options_.qz_criterium;
        info(1) = 3;
        info(2) = temp'*temp;
    end
    return;
end
%forward--looking models
if nstatic > 0
    [Q,R] = qr(b(:,1:nstatic));
    aa = Q'*jacobia_;
else
    aa = jacobia_;
end
a = aa(:,nonzeros(k1'));
b = aa(:,k0);
b10 = b(1:nstatic,1:nstatic);
b11 = b(1:nstatic,nstatic+1:end);
b2 = b(nstatic+1:end,nstatic+1:end);
if any(isinf(a(:)))
    info = 1;
    return
end

% buildind D and E
%nd
d = zeros(nd,nd) ;
e = d ;
k = find(kstate(:,2) >= M_.maximum_endo_lag+2 & kstate(:,3));
d(1:sdyn,k) = a(nstatic+1:end,kstate(k,3)) ;
k1 = find(kstate(:,2) == M_.maximum_endo_lag+2);
e(1:sdyn,k1) =  -b2(:,kstate(k1,1)-nstatic);
k = find(kstate(:,2) <= M_.maximum_endo_lag+1 & kstate(:,4));
e(1:sdyn,k) = -a(nstatic+1:end,kstate(k,4)) ;
k2 = find(kstate(:,2) == M_.maximum_endo_lag+1);
k2 = k2(~ismember(kstate(k2,1),kstate(k1,1)));
d(1:sdyn,k2) = b2(:,kstate(k2,1)-nstatic);

if ~isempty(kad)
    for j = 1:size(kad,1)
        d(sdyn+j,kad(j)) = 1 ;
        e(sdyn+j,kae(j)) = 1 ;
    end
end
%e
%d

[err,ss,tt,w,sdim,dr.eigval,info1] = mjdgges(e,d,options_.qz_criterium);
mexErrCheck('mjdgges', err);

if info1
    info(1) = 2;
    info(2) = info1;
    return
end

nba = nd-sdim;

nyf = sum(kstate(:,2) > M_.maximum_endo_lag+1);

if task == 1
    dr.rank = rank(w(1:nyf,nd-nyf+1:end));
    % Under Octave, eig(A,B) doesn't exist, and
    % lambda = qz(A,B) won't return infinite eigenvalues
    if ~exist('OCTAVE_VERSION')
        dr.eigval = eig(e,d);
    end
    return
end

if nba ~= nyf
    temp = sort(abs(dr.eigval));
    if nba > nyf
        temp = temp(nd-nba+1:nd-nyf)-1-options_.qz_criterium;
        info(1) = 3;
    elseif nba < nyf;
        temp = temp(nd-nyf+1:nd-nba)-1-options_.qz_criterium;
        info(1) = 4;
    end
    info(2) = temp'*temp;
    return
end

np = nd - nyf;
n2 = np + 1;
n3 = nyf;
n4 = n3 + 1;
% derivatives with respect to dynamic state variables
% forward variables
w1 =w(1:n3,n2:nd);
if condest(w1) > 1e9;
    info(1) = 5;
    info(2) = condest(w1);
    return;
else
    gx = -w1'\w(n4:nd,n2:nd)';
end  

% predetermined variables
hx = w(1:n3,1:np)'*gx+w(n4:nd,1:np)';
hx = (tt(1:np,1:np)*hx)\(ss(1:np,1:np)*hx);

k1 = find(kstate(n4:nd,2) == M_.maximum_endo_lag+1);
k2 = find(kstate(1:n3,2) == M_.maximum_endo_lag+2);
hx(k1,:)
gx(k2(nboth+1:end),:)
dr.ghx = [hx(k1,:); gx(k2(nboth+1:end),:)];
dr.ghx
%lead variables actually present in the model
j3 = nonzeros(kstate(:,3));
j4  = find(kstate(:,3));
% derivatives with respect to exogenous variables
disp(['M_.exo_nbr=' int2str(M_.exo_nbr)]);
if M_.exo_nbr
    fu = aa(:,nz+(1:M_.exo_nbr));
    a1 = b;
    aa1 = [];
    if nstatic > 0
        aa1 = a1(:,1:nstatic);
    end
    dr.ghu = -[aa1 a(:,j3)*gx(j4,1:npred)+a1(:,nstatic+1:nstatic+ ...
                                             npred) a1(:,nstatic+npred+1:end)]\fu;
else
    dr.ghu = [];
end

% static variables
if nstatic > 0
    temp = -a(1:nstatic,j3)*gx(j4,:)*hx;
    j5 = find(kstate(n4:nd,4));
    temp(:,j5) = temp(:,j5)-a(1:nstatic,nonzeros(kstate(:,4)));
    temp = b10\(temp-b11*dr.ghx);
    dr.ghx = [temp; dr.ghx];
    temp = [];
end

if options_.loglinear == 1
    k = find(dr.kstate(:,2) <= M_.maximum_endo_lag+1);
    klag = dr.kstate(k,[1 2]);
    k1 = dr.order_var;
    
    dr.ghx = repmat(1./dr.ys(k1),1,size(dr.ghx,2)).*dr.ghx.* ...
             repmat(dr.ys(k1(klag(:,1)))',size(dr.ghx,1),1);
    dr.ghu = repmat(1./dr.ys(k1),1,size(dr.ghu,2)).*dr.ghu;
end

%% Necessary when using Sims' routines for QZ
if options_.use_qzdiv
    gx = real(gx);
    hx = real(hx);
    dr.ghx = real(dr.ghx);
    dr.ghu = real(dr.ghu);
end

%exogenous deterministic variables
if M_.exo_det_nbr > 0
    f1 = sparse(jacobia_(:,nonzeros(M_.lead_lag_incidence(M_.maximum_endo_lag+2:end,order_var))));
    f0 = sparse(jacobia_(:,nonzeros(M_.lead_lag_incidence(M_.maximum_endo_lag+1,order_var))));
    fudet = sparse(jacobia_(:,nz+M_.exo_nbr+1:end));
    M1 = inv(f0+[zeros(M_.endo_nbr,nstatic) f1*gx zeros(M_.endo_nbr,nyf-nboth)]);
    M2 = M1*f1;
    dr.ghud = cell(M_.exo_det_length,1);
    dr.ghud{1} = -M1*fudet;
    for i = 2:M_.exo_det_length
        dr.ghud{i} = -M2*dr.ghud{i-1}(end-nyf+1:end,:);
    end
end
if options_.order == 1
    return
end

% Second order
%tempex = oo_.exo_simul ;

%hessian = real(hessext('ff1_',[z; oo_.exo_steady_state]))' ;
kk = flipud(cumsum(flipud(M_.lead_lag_incidence(M_.maximum_endo_lag+1:end,order_var)),1));
if M_.maximum_endo_lag > 0
    kk = [cumsum(M_.lead_lag_incidence(1:M_.maximum_endo_lag,order_var),1); kk];
end
kk = kk';
kk = find(kk(:));
nk = size(kk,1) + M_.exo_nbr + M_.exo_det_nbr;
k1 = M_.lead_lag_incidence(:,order_var);
k1 = k1';
k1 = k1(:);
k1 = k1(kk);
k2 = find(k1);
kk1(k1(k2)) = k2;
kk1 = [kk1 length(k1)+1:length(k1)+M_.exo_nbr+M_.exo_det_nbr];
kk = reshape([1:nk^2],nk,nk);
kk1 = kk(kk1,kk1);
%[junk,junk,hessian] = feval([M_.fname '_dynamic'],z, oo_.exo_steady_state);
hessian(:,kk1(:)) = hessian;

%oo_.exo_simul = tempex ;
%clear tempex

n1 = 0;
n2 = np;
zx = zeros(np,np);
zu=zeros(np,M_.exo_nbr);
for i=2:M_.maximum_endo_lag+1
    k1 = sum(kstate(:,2) == i);
    zx(n1+1:n1+k1,n2-k1+1:n2)=eye(k1);
    n1 = n1+k1;
    n2 = n2-k1;
end
kk = flipud(cumsum(flipud(M_.lead_lag_incidence(M_.maximum_endo_lag+1:end,order_var)),1));
k0 = [1:M_.endo_nbr];
gx1 = dr.ghx;
hu = dr.ghu(nstatic+[1:npred],:);
zx = [zx; gx1];
zu = [zu; dr.ghu];
for i=1:M_.maximum_endo_lead
    k1 = find(kk(i+1,k0) > 0);
    zu = [zu; gx1(k1,1:npred)*hu];
    gx1 = gx1(k1,:)*hx;
    zx = [zx; gx1];
    kk = kk(:,k0);
    k0 = k1;
end
zx=[zx; zeros(M_.exo_nbr,np);zeros(M_.exo_det_nbr,np)];
zu=[zu; eye(M_.exo_nbr);zeros(M_.exo_det_nbr,M_.exo_nbr)];
[nrzx,nczx] = size(zx);

rhs = -sparse_hessian_times_B_kronecker_C(hessian,zx);

%lhs
n = M_.endo_nbr+sum(kstate(:,2) > M_.maximum_endo_lag+1 & kstate(:,2) < M_.maximum_endo_lag+M_.maximum_endo_lead+1);
A = zeros(n,n);
B = zeros(n,n);
A(1:M_.endo_nbr,1:M_.endo_nbr) = jacobia_(:,M_.lead_lag_incidence(M_.maximum_endo_lag+1,order_var));
% variables with the highest lead
k1 = find(kstate(:,2) == M_.maximum_endo_lag+M_.maximum_endo_lead+1);
if M_.maximum_endo_lead > 1
    k2 = find(kstate(:,2) == M_.maximum_endo_lag+M_.maximum_endo_lead);
    [junk,junk,k3] = intersect(kstate(k1,1),kstate(k2,1));
else
    k2 = [1:M_.endo_nbr];
    k3 = kstate(k1,1);
end
% Jacobian with respect to the variables with the highest lead
B(1:M_.endo_nbr,end-length(k2)+k3) = jacobia_(:,kstate(k1,3)+M_.endo_nbr);
offset = M_.endo_nbr;
k0 = [1:M_.endo_nbr];
gx1 = dr.ghx;
for i=1:M_.maximum_endo_lead-1
    k1 = find(kstate(:,2) == M_.maximum_endo_lag+i+1);
    [k2,junk,k3] = find(kstate(k1,3));
    A(1:M_.endo_nbr,offset+k2) = jacobia_(:,k3+M_.endo_nbr);
    n1 = length(k1);
    A(offset+[1:n1],nstatic+[1:npred]) = -gx1(kstate(k1,1),1:npred);
    gx1 = gx1*hx;
    A(offset+[1:n1],offset+[1:n1]) = eye(n1);
    n0 = length(k0);
    E = eye(n0);
    if i == 1
        [junk,junk,k4]=intersect(kstate(k1,1),[1:M_.endo_nbr]);
    else
        [junk,junk,k4]=intersect(kstate(k1,1),kstate(k0,1));
    end
    i1 = offset-n0+n1;
    B(offset+[1:n1],offset-n0+[1:n0]) = -E(k4,:);
    k0 = k1;
    offset = offset + n1;
end
[junk,k1,k2] = find(M_.lead_lag_incidence(M_.maximum_endo_lag+M_.maximum_endo_lead+1,order_var));
A(1:M_.endo_nbr,nstatic+1:nstatic+npred)=...
    A(1:M_.endo_nbr,nstatic+[1:npred])+jacobia_(:,k2)*gx1(k1,1:npred);
C = hx;
D = [rhs; zeros(n-M_.endo_nbr,size(rhs,2))];


dr.ghxx = gensylv(2,A,B,C,D);

%ghxu
%rhs
hu = dr.ghu(nstatic+1:nstatic+npred,:);
%kk = reshape([1:np*np],np,np);
%kk = kk(1:npred,1:npred);
%rhs = -hessian*kron(zx,zu)-f1*dr.ghxx(end-nyf+1:end,kk(:))*kron(hx(1:npred,:),hu(1:npred,:));

rhs = sparse_hessian_times_B_kronecker_C(hessian,zx,zu);

nyf1 = sum(kstate(:,2) == M_.maximum_endo_lag+2);
hu1 = [hu;zeros(np-npred,M_.exo_nbr)];
%B1 = [B(1:M_.endo_nbr,:);zeros(size(A,1)-M_.endo_nbr,size(B,2))];
[nrhx,nchx] = size(hx);
[nrhu1,nchu1] = size(hu1);

[err, abcOut] = A_times_B_kronecker_C(dr.ghxx,hx,hu1);
mexErrCheck('A_times_B_kronecker_C', err);
B1 = B*abcOut;
rhs = -[rhs; zeros(n-M_.endo_nbr,size(rhs,2))]-B1;


%lhs
dr.ghxu = A\rhs;

%ghuu
%rhs
kk = reshape([1:np*np],np,np);
kk = kk(1:npred,1:npred);

rhs = sparse_hessian_times_B_kronecker_C(hessian,zu);


[err, B1] = A_times_B_kronecker_C(B*dr.ghxx,hu1);
mexErrCheck('A_times_B_kronecker_C', err);
rhs = -[rhs; zeros(n-M_.endo_nbr,size(rhs,2))]-B1;

%lhs
dr.ghuu = A\rhs;

dr.ghxx = dr.ghxx(1:M_.endo_nbr,:);
dr.ghxu = dr.ghxu(1:M_.endo_nbr,:);
dr.ghuu = dr.ghuu(1:M_.endo_nbr,:);


% dr.ghs2
% derivatives of F with respect to forward variables
% reordering predetermined variables in diminishing lag order
O1 = zeros(M_.endo_nbr,nstatic);
O2 = zeros(M_.endo_nbr,M_.endo_nbr-nstatic-npred);
LHS = jacobia_(:,M_.lead_lag_incidence(M_.maximum_endo_lag+1,order_var));
RHS = zeros(M_.endo_nbr,M_.exo_nbr^2);
kk = find(kstate(:,2) == M_.maximum_endo_lag+2);
gu = dr.ghu; 
guu = dr.ghuu; 
Gu = [dr.ghu(nstatic+[1:npred],:); zeros(np-npred,M_.exo_nbr)];
Guu = [dr.ghuu(nstatic+[1:npred],:); zeros(np-npred,M_.exo_nbr*M_.exo_nbr)];
E = eye(M_.endo_nbr);
M_.lead_lag_incidenceordered = flipud(cumsum(flipud(M_.lead_lag_incidence(M_.maximum_endo_lag+1:end,order_var)),1));
if M_.maximum_endo_lag > 0
    M_.lead_lag_incidenceordered = [cumsum(M_.lead_lag_incidence(1:M_.maximum_endo_lag,order_var),1); M_.lead_lag_incidenceordered];
end
M_.lead_lag_incidenceordered = M_.lead_lag_incidenceordered';
M_.lead_lag_incidenceordered = M_.lead_lag_incidenceordered(:);
k1 = find(M_.lead_lag_incidenceordered);
M_.lead_lag_incidenceordered(k1) = [1:length(k1)]';
M_.lead_lag_incidenceordered =reshape(M_.lead_lag_incidenceordered,M_.endo_nbr,M_.maximum_endo_lag+M_.maximum_endo_lead+1)';
kh = reshape([1:nk^2],nk,nk);
kp = sum(kstate(:,2) <= M_.maximum_endo_lag+1);
E1 = [eye(npred); zeros(kp-npred,npred)];
H = E1;
hxx = dr.ghxx(nstatic+[1:npred],:);
for i=1:M_.maximum_endo_lead
    for j=i:M_.maximum_endo_lead
        [junk,k2a,k2] = find(M_.lead_lag_incidence(M_.maximum_endo_lag+j+1,order_var));
        [junk,k3a,k3] = ...
            find(M_.lead_lag_incidenceordered(M_.maximum_endo_lag+j+1,:));
        nk3a = length(k3a);
        B1 = sparse_hessian_times_B_kronecker_C(hessian(:,kh(k3,k3)),gu(k3a,:));
        RHS = RHS + jacobia_(:,k2)*guu(k2a,:)+B1;
    end
    % LHS
    [junk,k2a,k2] = find(M_.lead_lag_incidence(M_.maximum_endo_lag+i+1,order_var));
    LHS = LHS + jacobia_(:,k2)*(E(k2a,:)+[O1(k2a,:) dr.ghx(k2a,:)*H O2(k2a,:)]);
    
    if i == M_.maximum_endo_lead 
        break
    end
    
    kk = find(kstate(:,2) == M_.maximum_endo_lag+i+1);
    gu = dr.ghx*Gu;
    [nrGu,ncGu] = size(Gu);
    [err, G1] = A_times_B_kronecker_C(dr.ghxx,Gu);
    mexErrCheck('A_times_B_kronecker_C', err);
    [err, G2] = A_times_B_kronecker_C(hxx,Gu);
    mexErrCheck('A_times_B_kronecker_C', err);
    guu = dr.ghx*Guu+G1;
    Gu = hx*Gu;
    Guu = hx*Guu;
    Guu(end-npred+1:end,:) = Guu(end-npred+1:end,:) + G2;
    H = E1 + hx*H;
end
RHS = RHS*M_.Sigma_e(:);
dr.fuu = RHS;
%RHS = -RHS-dr.fbias;
RHS = -RHS;
dr.ghs2 = LHS\RHS;

% deterministic exogenous variables
if M_.exo_det_nbr > 0
    hud = dr.ghud{1}(nstatic+1:nstatic+npred,:);
    zud=[zeros(np,M_.exo_det_nbr);dr.ghud{1};gx(:,1:npred)*hud;zeros(M_.exo_nbr,M_.exo_det_nbr);eye(M_.exo_det_nbr)];
    R1 = hessian*kron(zx,zud);
    dr.ghxud = cell(M_.exo_det_length,1);
    kf = [M_.endo_nbr-nyf+1:M_.endo_nbr];
    kp = nstatic+[1:npred];
    dr.ghxud{1} = -M1*(R1+f1*dr.ghxx(kf,:)*kron(dr.ghx(kp,:),dr.ghud{1}(kp,:)));
    Eud = eye(M_.exo_det_nbr);
    for i = 2:M_.exo_det_length
        hudi = dr.ghud{i}(kp,:);
        zudi=[zeros(np,M_.exo_det_nbr);dr.ghud{i};gx(:,1:npred)*hudi;zeros(M_.exo_nbr+M_.exo_det_nbr,M_.exo_det_nbr)];
        R2 = hessian*kron(zx,zudi);
        dr.ghxud{i} = -M2*(dr.ghxud{i-1}(kf,:)*kron(hx,Eud)+dr.ghxx(kf,:)*kron(dr.ghx(kp,:),dr.ghud{i}(kp,:)))-M1*R2;
    end
    R1 = hessian*kron(zu,zud);
    dr.ghudud = cell(M_.exo_det_length,1);
    kf = [M_.endo_nbr-nyf+1:M_.endo_nbr];
    
    dr.ghuud{1} = -M1*(R1+f1*dr.ghxx(kf,:)*kron(dr.ghu(kp,:),dr.ghud{1}(kp,:)));
    Eud = eye(M_.exo_det_nbr);
    for i = 2:M_.exo_det_length
        hudi = dr.ghud{i}(kp,:);
        zudi=[zeros(np,M_.exo_det_nbr);dr.ghud{i};gx(:,1:npred)*hudi;zeros(M_.exo_nbr+M_.exo_det_nbr,M_.exo_det_nbr)];
        R2 = hessian*kron(zu,zudi);
        dr.ghuud{i} = -M2*dr.ghxud{i-1}(kf,:)*kron(hu,Eud)-M1*R2;
    end
    R1 = hessian*kron(zud,zud);
    dr.ghudud = cell(M_.exo_det_length,M_.exo_det_length);
    dr.ghudud{1,1} = -M1*R1-M2*dr.ghxx(kf,:)*kron(hud,hud);
    for i = 2:M_.exo_det_length
        hudi = dr.ghud{i}(nstatic+1:nstatic+npred,:);
        zudi=[zeros(np,M_.exo_det_nbr);dr.ghud{i};gx(:,1:npred)*hudi+dr.ghud{i-1}(kf,:);zeros(M_.exo_nbr+M_.exo_det_nbr,M_.exo_det_nbr)];
        R2 = hessian*kron(zudi,zudi);
        dr.ghudud{i,i} = -M2*(dr.ghudud{i-1,i-1}(kf,:)+...
                              2*dr.ghxud{i-1}(kf,:)*kron(hudi,Eud) ...
                              +dr.ghxx(kf,:)*kron(hudi,hudi))-M1*R2;
        R2 = hessian*kron(zud,zudi);
        dr.ghudud{1,i} = -M2*(dr.ghxud{i-1}(kf,:)*kron(hud,Eud)+...
                              dr.ghxx(kf,:)*kron(hud,hudi))...
            -M1*R2;
        for j=2:i-1
            hudj = dr.ghud{j}(kp,:);
            zudj=[zeros(np,M_.exo_det_nbr);dr.ghud{j};gx(:,1:npred)*hudj;zeros(M_.exo_nbr+M_.exo_det_nbr,M_.exo_det_nbr)];
            R2 = hessian*kron(zudj,zudi);
            dr.ghudud{j,i} = -M2*(dr.ghudud{j-1,i-1}(kf,:)+dr.ghxud{j-1}(kf,:)* ...
                                  kron(hudi,Eud)+dr.ghxud{i-1}(kf,:)* ...
                                  kron(hudj,Eud)+dr.ghxx(kf,:)*kron(hudj,hudi))-M1*R2;
        end
        
    end
end