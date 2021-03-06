
% Train Delay Rescheduling w/ Passenger Weighting

% Original Author : MiniZinc Benchmarks 
%        Modified : Kieran Molloy 02/12/2019

%----------------------------------------------------------------------------%
% Suggested Data Files

% Basic_n1.dzn
% Basic_n3.dzn
% Basic_n5.dzn
% Basic_n10.dzn
% Basic_n50.dzn
% Basic_n100.dzn
% Basic_n200.dzn
% Basic_n10m10.dzn
% Liverpool_Manchester_North.dzn
% Liverpool_Manchester_North_nodelay.dzn

%----------------------------------------------------------------------------%
% Variables

% Number of Trains
int : n;
% Number of Stations
int : m;

% Maximum Simulation Time
int : maxTime;
% Maximum Simulation Capacity
int : capacity;

% Time of Delay
0..maxTime : delayTime;
% Intial Delayed Train
1..n : delayTrain;
% Duration of Delay
0..maxTime : delayDuration;

% Distance between stations m -> (m-1)
array [1..m-1] of 0..maxTime : distance;

% Original Scheduled Arrival of Train n at Station m 
array [1..n, 1..m] of 0..maxTime : scheduledArrival;
% Original Scheduled Departure of Train n at Station m
array [1..n, 1..m] of 0..maxTime : scheduledDeparture;

% Time to Load Passengers at Station m
array [1..m] of 0..maxTime : passengerStart;
array [1..m] of 0..maxTime : passengerStop = [scheduledDeparture[n,j] | j in 1..m];
% Number of Passengers at Station m
array [1..m] of int : passengerFlow;

% New Arrival Time of Train n at Station m
array [1..n, 1..m] of var 0..maxTime : departure;
% New Departure Time of Train n at Station m
array [1..n, 1..m] of var 0..maxTime : arrival;

% Final Destination Time of Train n at station M
array [1..n] of var 0..maxTime : finalArrival = [ arrival[i,m] | i in 1..n ];

array [1..n, 1..m] of var 0..maxTime : sigmaLower;
array [1..n, 1..m] of var 0..maxTime : sigmaUpper;

% Dwell Time of Train n at Station m
array [1..n, 1..m] of var 0..maxTime : dwell;



% Number of Passengers collected at station m 
array [1..n, 1..m] of var 0..capacity : collect;
% Total Passengers on board
array [1..n, 1..m] of var 0..capacity : load;

%----------------------------------------------------------------------------%
% Objective Function

int: objective_min = lb(sum(i in 1..n)(load[i,m]*arrival[i,m]));
int: objective_max = ub(sum(i in 1..n)(load[i,m]*arrival[i,m]));
var objective_min..objective_max: objective = sum(i in 1..n)(load[i,m]*arrival[i,m]);

%----------------------------------------------------------------------------%
% Constraints

% All trains "arrive" at the first station at time 0.
constraint forall (i in 1..n)
        (arrival[i,1] = 0);
% ... and "depart" from the last station as soon as they arrive there.
constraint forall (i in 1..n)
        (departure[i,m] = arrival[i,m]);

% Before the delay, everything runs to schedule.
constraint forall (i in 1..n, j in 1..m-1)
        (if scheduledDeparture[i,j] <= delayTime
           then departure[i,j] = scheduledDeparture[i,j]
           else true
         endif);


int : destinationWhenDelayed = min([j | j in 1..m where scheduledDeparture[delayTrain,j] > delayTime]);
% If the train is in motion, then the arrival of the
% delayed train is at least the departure time at the previous station
% plus the ordinary travel time plus the duration of the delay.
constraint if destinationWhenDelayed > 1
           then if delayTime < scheduledDeparture[delayTrain,destinationWhenDelayed-1] + distance[destinationWhenDelayed-1]
               then arrival[delayTrain,destinationWhenDelayed] >=
                      departure[delayTrain,destinationWhenDelayed-1] + delayDuration + distance[destinationWhenDelayed-1]
               else true
               endif
           else true
           endif;
% The train's next departure is at least the delay time plus the delay
% duration.
constraint departure[delayTrain, destinationWhenDelayed] >= delayTime + delayDuration;

% Trains depart after they arrive. 
constraint forall (i in 1..n, j in 1..m)
        (departure[i,j] >= arrival[i,j]);

% Trains never leave earlier than scheduled.
constraint forall (i in 1..n, j in 1..m-1)
        (departure[i,j] >= scheduledDeparture[i,j]);

% There is a minimum travel time between stations.
constraint forall (i in 1..n, j in 1..m-1)
        (arrival[i,j+1] >= departure[i,j] + distance[j]);

% At station 1, trains leave in order.
constraint forall (i in 1..n-1)
        (departure[i,1] < departure[i+1,1]);
% At most one train dwelling at a station at a given time.
constraint forall (i in 1..n-1, j in 2..m-1)
        (departure[i,j] <= arrival[i+1,j]-2);

% The sigma values partition time at each station.
constraint forall (i in 1..n, j in 1..m)
        (sigmaLower[i,j] <= sigmaUpper[i,j]);

% For the first and last trains, the sigma values are equal to the
% extreme times of passenger arrivals.
constraint forall (j in 2..m-1)
        ((sigmaLower[1,j] = passengerStart[j])
     /\ (sigmaUpper[n,j] = scheduledDeparture[n,j]));
% The sigma values join together.
constraint forall (i in 1..n-1, j in 1..m)
        (sigmaUpper[i,j] = sigmaLower[i+1,j]);

% You can't pick up people after you leave.
constraint forall (i in 1..n-1, j in 1..m-1)
         (sigmaUpper[i,j] <= departure[i,j]);
constraint forall (j in 1..m-1)
        (sigmaUpper[n,j] <= departure[n,j]);

% Defines collect and load variables.
constraint forall (i in 1..n, j in 1..m)
        (collect[i,j] = (sigmaUpper[i,j]-sigmaLower[i,j])*passengerFlow[j]);

constraint forall (i in 1..n) 
        (load[i,1] = collect[i,1]);
constraint forall (i in 1..n, j in 2..m)
        (load[i,j] = load[i,j-1] + collect[i,j]);

% If a train picks anyone up, then it must pick
% everyone up (until it gets full).
constraint forall (i in 1..n, j in 1..m-1)
        (sigmaUpper[i,j] > sigmaLower[i,j] ->
             ((sigmaUpper[i,j] = departure[i,j]) \/
              (sigmaUpper[i,j] = scheduledDeparture[n,j]) \/
              (load[i,j] + bool2int(sigmaUpper[i,j] < scheduledDeparture[n,j])*passengerFlow[j] > capacity)));

% Boarding time.
constraint forall (i in 1..n, j in 2..m)
        (((capacity-load[i,j-1] < 100) -> (collect[i,j] <= dwell[i,j]*20)) /\
         ((capacity-load[i,j-1] >= 100) -> (collect[i,j] <= dwell[i,j]*50)));
% (Redundant for j>=2 (but necessary for j=1))
constraint forall (i in 1..n, j in 1..m)
        (collect[i,j] <= (departure[i,j]-arrival[i,j])*50);


constraint forall (i in 1..n, j in 1..m)
        (dwell[i,j] = departure[i,j] - arrival[i,j]);



solve 
    :: seq_search([
        int_search(
            [arrival[i,m-j+1] | j in 1..m, i in 1..n] ++
            [departure[i,m-j+1] | j in 1..m, i in 1..n] ++
            [sigmaUpper[i,m-j+1] | j in 1..m, i in 1..n] ++
            [sigmaLower[i,m-j+1] | j in 1..m, i in 1..n],
            input_order, indomain_min, complete
        ),
        int_search(
            array1d(1..n*m, collect) ++ array1d(1..n*m, load) ++ array1d(1..n*m, dwell),
            first_fail, indomain_min, complete
        )
    ])
    minimize objective;

output [
    "arrival = array2d(1..", show(n), ", 1..", show(m), ", ", show(arrival), ");\n",
    "departure = array2d(1..", show(n), ", 1..", show(m), ", ", show(departure), ");\n",
    "sigmaLower = array2d(1..", show(n), ", 1..", show(m), ", ", show(sigmaLower), ");\n",
    "sigmaUpper = array2d(1..", show(n), ", 1..", show(m), ", ", show(sigmaUpper), ");\n",
    "collect = array2d(1..", show(n), ", 1..", show(m), ", ", show(collect), ");\n",
    "load = array2d(1..", show(n), ", 1..", show(m), ", ", show(load), ");\n",
    "dwell = array2d(1..", show(n), ", 1..", show(m), ", ", show(dwell), ");\n",
    "constraint objective = ", show(objective), ";\n"
];

