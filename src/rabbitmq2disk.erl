-module(rabbitmq2disk).
-behaviour(gen_server).
-behaviour(kiks_consumer_protocol).

%% API
-export([start_link/2,
	 process/4]).

%% Behaviour callbacks
-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3]).

%%------------------------------------------------------------------------------
%% API
%%------------------------------------------------------------------------------

start_link(Root) ->
    gen_server:start_link(?MODULE, Root, []).

process(Tag, Pid, Payload, Topic) ->
    gen_server:call(Pid, {process, Tag, Payload, Topic}).

%%-----------------------------------------------------------------------------
%% Behaviour callbacks
%%------------------------------------------------------------------------------

%% @hidden
init(Root) ->
    {ok, Fs} = erlmemfs_sup:create_erlmemfs(),
    {ok, _CD} = kiks_consumer_sup:add_child(data, "ftpdata", Name, "#", ?MODULE, self()),
    {ok, _CI} = kiks_consumer_sup:add_child(info, "ftpinfo", Name, "#", ?MODULE, self()),
    {ok, #{root => Root, fs => Fs}}.

%% @hidden
handle_call({process, info, Payload, Topic}, _From, State) ->
    lager:warning("received info"),
    {reply, ok, State};

handle_call({process, data, Payload, Topic}, _From, State) ->
    lager:warning("received data"),
    {reply, ok, State};

handle_call(What, _From, State) ->
    {reply, {error, What}, State}.

%% @hidden
handle_cast(_What, State) ->
    {noreply, State}.

%% @hidden
handle_info(_What, State) ->
    {noreply, State}.

%% @hidden
terminate(_Reason, _State) ->
    ok.

%% @hidden
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
