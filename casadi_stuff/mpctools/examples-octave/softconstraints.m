% On/off control of a tank with softened constraints.
mpc = import_mpctools();

s = tf('s');
N = {[0 2] [0 2];[0 1] [0 -4]};
D = {[10 1] [1 1];[1 1] [1 1]};
systf = tf(N,D);
sysss = ss(systf);
A = sysss.A;
B = sysss.B;
C = sysss.C;
D = sysss.D;
x0 = [1;1;1];
Delta = 0.5;
Q = eye(rank(sysss.A));
S = eye(rank(sysss.A));
R = eye(rank(sysss.B));
Nx = size(A, 2);
Nu = size(B, 2);
Ns = 2*Nx; % One for each bound.
Nt = 25;

N = struct('x', Nx, 'u', Nu, 't', Nt, 's', Ns);

% Casadi functions for model, stage cost, and constraints.
f = mpc.getCasadiFunc(@(x, u) A*x + B*u, [Nx, Nu], {'x', 'u'}, {'f'});
l = mpc.getCasadiFunc(@(x, u) x'*Q*x + u'*R*u, [Nx, Nu], ...
                      {'s', 'absDu'}, {'l'});
Vf = mpc.getCasadiFunc(@(x) x'*P*x, ...
                      [Nx], {'x'}, {'Vf'});
ef = Vf; % Use same constraint for terminal state.

% Specify bounds.
lb = struct();
lb.u = ones(Nu, Nt);
% lb.x = zeros(Nx, Nt + 1);

ub = struct();
ub.u = -1*ones(Nu, Nt);
% ub.x = hmax*ones(Nx, Nt + 1);
udiscrete = false();
% Build controller and solve.
if udiscrete
    solver = 'gurobi';
else
    solver = 'ipopt';
end
x0 = zeros(Nx, 1); % Start with empty tank.
controller = mpc.nmpc('f', f, 'l', l, 'Vf', Vf, 'ef', ef, 'N', N, 'lb', lb, ...
                      'ub', ub, 'uprev', zeros(Nu, 1), 'isQP', true(), ...
                      'x0', x0, 'udiscrete', udiscrete, 'solver', solver);
controller.solve()

% Make a plot.
figure();
x = controller.var.x;
u = controller.var.u;

subplot(2, 1, 1);
plot(0:Nt, x, '-ok', [0, Nt], (hsp + hdb)*[1, 1], ':b', ...
     [0, Nt], (hsp - hdb)*[1, 1], ':b');
ylabel('h', 'rotation', 0);
legend('h', 'h_{db}', 'Location', 'SouthEast');

subplot(2, 1, 2);
hold('on');
stairs(0:Nt, [u, u(:,end)], '-k');
plot([0, Nt], qmax*[1, 1], '--b', [0, Nt], 0*[1, 1], '--b');
axis([0, Nt, -0.1, 0.1 + qmax]);
xlabel('Time');
ylabel('q', 'rotation', 0);
legend('q', 'q_{bounds}', 'Location', 'North');

