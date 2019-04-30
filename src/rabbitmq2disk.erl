-module(rabbitmq2disk).
-behaviour(gen_server).
-behaviour(kiks_consumer_protocol).

%% API
-export([start_link/1,
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

-record(state, {
	  root,
	  fs,
	  hashtable = #{},
	  blobs = #{}
	 }).

-record(hashinfo, {
	  username,
	  path,
	  hash,
	  filename
	 }).

%% @hidden
init(Root) ->
    {ok, Fs} = erlmemfs_sup:create_erlmemfs(),
    {ok, _CD} = kiks_consumer_sup:add_child(data, "ftpdata", "data1", "#", ?MODULE, self()),
    {ok, _CI} = kiks_consumer_sup:add_child(info, "ftpinfo", "info1", "#", ?MODULE, self()),
    {ok, #state{root=Root, fs=Fs}}.

%% @hidden
handle_call({process, info, Payload, _Topic}, _From, State) ->
    lager:warning("received info"),
    HashInfo = payload_to_record(Payload),
    {reply, ok, add_record(State, HashInfo), 0};

handle_call({process, data, Payload, _Topic}, _From, State) ->
    lager:warning("received data"),
    Hash = erlmemfs_support:hash(Payload),
    #state{hashtable=HashTable} = State,
    Status = map:get(Hash, HashTable, {badkey, Hash}),
    {reply, ok, resolve_data(State, Status, Payload)};

handle_call(What, _From, State) ->
    {reply, {error, What}, State}.

%% @hidden
handle_cast(_What, State) ->
    {noreply, State}.

%% @hidden
handle_info(timeout, State) ->
    lager:warning("resolve data"),
    {noreply, State};

handle_info(_What, State) ->
    {noreply, State}.

%% @hidden
terminate(_Reason, _State) ->
    ok.

%% @hidden
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%-----------------------------------------------------------------------------
%% Behaviour callbacks
%%------------------------------------------------------------------------------

payload_to_record(Payload) ->
    Info = jiffy:decode(Payload),
    {[{<<"username">>, Username},
      {<<"path">>, Path},
      {<<"hash">>, Hash},
      {<<"filename">>, Filename}]} = Info,
    #hashinfo{username=Username,
	      path=Path,
	      hash=Hash,
	      filename=Filename}.

add_record(State=#state{hashtable=HashTable}, Record=#hashinfo{hash=Hash}) ->
    State#state{hashtable=maps:put(Hash, Record, HashTable)}.

resolve_data(State=#state{blobs=Blobs}, {badkey, Hash}, Payload) ->
    State#state{blobs=Blobs#{Hash => Payload}};

resolve_data(State=#state{root=Root}, Info, Payload) ->
    #hashinfo{path=Path,
	      filename=Filename} = Info,
    FullPath = filename:join([Root, Path]),
    FullFile = filename:join([Root, Path, Filename]),
    filelib:ensure_dir(FullPath),
    file:write_file(FullFile, Payload),
    State.
