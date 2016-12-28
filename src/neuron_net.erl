-module(neuron_net).

-compile(export_all).

-include("records.hrl").


%% Layers list: e.g [1, 3, 1]
%% Acc -> [
%%  {Pid, In_ids, Out_ids}
%% ]
new(Layers) ->
  Cortex = cortex:new(),
  Ref = make_ref(),

  Actuators = [actuator:new(Cortex, Key) || Key <- lists:seq(1, 4)],
  Cortex ! {self(), Ref, set, actuators, Actuators},
  cortex:sync(Cortex, Ref),

  %% [4] is for the actuators,
  %% [1] is for the input layer.
  Net = new_net(Cortex, [1|Layers] ++ [4], 480*420),
  Cortex ! {self(), Ref, set, net, Net},
  cortex:sync(Cortex, Ref),

  Cortex ! {self(), Ref, set, neuron_num, lists:sum(Layers) + 5},
  cortex:sync(Cortex, Ref),

  Sensor = sensor:new(Cortex),
  Cortex ! {self(), Ref, set, sensor, Sensor},
  cortex:sync(Cortex, Ref),

  Cortex.


new_ffnn(Layers) ->
  Cortex = cortex:new(),
  Ref = make_ref(),

  Actuators = [actuator:new_pts(Cortex)],
  Cortex ! {self(), Ref, set, actuators, Actuators},
  cortex:sync(Cortex, Ref),

  %% [1] is for the actuators,
  %% [1] is for the input layer.
  Net = new_net(Cortex, [1|Layers] ++ [1], 400),
  Cortex ! {self(), Ref, set, net, Net},
  cortex:sync(Cortex, Ref),

  Cortex ! {self(), Ref, set, neuron_num, lists:sum(Layers) + 2},
  cortex:sync(Cortex, Ref),

  Sensor = sensor:new_rng(Cortex, 10000),
  Cortex ! {self(), Ref, set, sensor, Sensor},
  cortex:sync(Cortex, Ref),

  Cortex.


copy(OldCortex) ->
  Cortex = cortex:new(),
  Ref = make_ref(),

  Actuators = [actuator:new(Cortex, Key) || Key <- lists:seq(1, 4)],
  Cortex ! {self(), Ref, set, actuators, Actuators},
  cortex:sync(Cortex, Ref),

  OldCortex ! {self(), Ref, get, net},
  receive
    {OldCortex, Ref, Net, NeuronNum} -> ok
  end,

  Cortex ! {self(), Ref, set, net, copy_net(Cortex, Net)},
  cortex:sync(Cortex, Ref),

  Cortex ! {self(), Ref, set, neuron_num, NeuronNum},
  cortex:sync(Cortex, Ref),

  Sensor = sensor:new(Cortex),
  Cortex ! {self(), Ref, set, sensor, Sensor},
  error_logger:info_msg("sensor: ~p~n", [Sensor]),
  cortex:sync(Cortex, Ref),

  Cortex.


copy_net(Cortex, Net) -> copy_net(Cortex, Net, []).

copy_net(_, [], Acc) -> lists:reverse(Acc);

copy_net(Cortex, [Layer|T], Acc) ->
  copy_net(Cortex, T, [copy_net_layer(Cortex, Layer)|Acc]).


copy_net_layer(Cortex, Layer) -> copy_net_layer(Cortex, Layer, []).

copy_net_layer(_, [], Acc) -> lists:reverse(Acc);

copy_net_layer(Cortex, [{_, N}|T], Acc) ->
  copy_net_layer(Cortex, T, [neuron:new(N#neuron{cortex=Cortex})|Acc]).


new_net(Cortex, Layers, InputVecLen) ->
  new_net(Cortex, Layers, InputVecLen, []).

new_net(_, [], _, Acc) -> lists:reverse(Acc);

new_net(Cortex, _Layers=[H|T], VecLen, Acc) ->
  Layer = new_net_layer(Cortex, VecLen, H),
  new_net(Cortex, T, H, [Layer|Acc]).


%% create a single network layer
new_net_layer(Cortex, VecLen, Count) -> new_net_layer(Cortex, VecLen, Count, []).

new_net_layer(_, _, 0, Acc) -> lists:reverse(Acc);

new_net_layer(Cortex, VecLen, Count, Acc) ->
  Neuron = neuron:new(Cortex, VecLen, Count),
  new_net_layer(Cortex, VecLen, Count- 1, [Neuron|Acc]).


mutate(_, 0) -> ok;

mutate(Net, Count) ->
  case mutate_ops() of
    weights ->
      LayerN = rand:uniform(length(Net)),
      Layer = lists:nth(LayerN, Net),
      {Pid, _} = lists:nth(rand:uniform(length(Layer)), Layer),
      Pid ! {self(), ch_weight},
      receive
        {Pid, ok} -> ok
      end
  end,
  mutate(Net, Count - 1).


mutate_ops() -> element(rand:uniform(1), {weights}).
