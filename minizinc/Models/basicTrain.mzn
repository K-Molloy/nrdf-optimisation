
% Train Delay Rescheduling

% Original Author : MiniZinc Benchmarks 
%        Modified : Kieran Molloy 21/12/2019

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

% We have n trains moving along a single track with m stations. There is a
% non-zero constant flow of passengers arriving at all but the first and last
% station who wish to travel to the final station.   Trains are originally
% scheduled so that they collect the passengers and drop them at the final
% station.  To this original schedule a disruption is introduced whereby a train
% is delayed. Each of the trains (at the time of the delay) has knowledge of the
% duration of the delay. The objective is to reschedule the trains to minimize
% the average travel time of the passengers. Trains are not able to overtake
% preceding trains, however they do have the option to
% skip a station and wait longer at a station to collect more passengers.

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

% Dwell Time of Train n at Station m
array [1..n, 1..m] of var 0..maxTime : dwell;


%----------------------------------------------------------------------------%
% Objective Function

int: objective_min = lb(sum(i in 1..n)(arrival[i,m]-scheduledArrival[i,m]));
int: objective_max = ub(sum(i in 1..n)(arrival[i,m]-scheduledArrival[i,m]));
var objective_min..objective_max: objective = sum(i in 1..n)(arrival[i,m]-scheduledArrival[i,m]);

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

% Dwell Time
constraint forall (i in 1..n, j in 1..m) 
        (dwell[i,j] = departure[i,j] - arrival[i,j]);


%----------------------------------------------------------------------------%
% Solve
solve 
    :: seq_search([
        int_search(
            [arrival[i,m-j+1] | j in 1..m, i in 1..n] ++
            [departure[i,m-j+1] | j in 1..m, i in 1..n],
            input_order, indomain_min, complete
        ),
    ])
    minimize objective;
%----------------------------------------------------------------------------%
% Output
output [
    "arrival = array2d(1..", show(n), ", 1..", show(m), ", ", show(arrival), ");\n",
    "departure = array2d(1..", show(n), ", 1..", show(m), ", ", show(departure), ");\n",
    "dwell = array2d(1..", show(n), ", 1..", show(m), ", ", show(dwell), ");\n",
    "constraint objective = ", show(objective), ";\n"
];