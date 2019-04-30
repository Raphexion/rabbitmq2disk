%%%-------------------------------------------------------------------
%% @doc rabbitmq2disk top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(rabbitmq2disk_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    Children = [#{id => rabbitmq2disk,
		  start => {rabbitmq2disk, start_link, ["/tmp"]}}],
    {ok, { {one_for_all, 1, 1}, Children} }.

%%====================================================================
%% Internal functions
%%====================================================================
