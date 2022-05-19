%%%----------------------------------------------------------------------
%%% File    : mod_offline_http_caller.erl
%%% Author  : Bruno Faundez <bruno@ferativ.com>
%%% Purpose : Call http endpoint on offline messages
%%% Created : 19 May 2022 by Bruno Faúndez <bruno@ferativ.com>
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License along
%%% with this program; if not, write to the Free Software Foundation, Inc.,
%%% 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
%%%
%%%----------------------------------------------------------------------

-module(mod_offline_http_caller).

-behaviour(gen_mod).

%% Required by ?INFO_MSG macros
-include("logger.hrl").

-include_lib("xmpp/include/xmpp.hrl").

%% Used to compare string equality
-import(string,[equal/2]). 

%% Required by ?T macro
-include("translate.hrl").

%% gen_mod API callbacks
-export([start/2,
         stop/1,
         depends/2,
         mod_opt_type/1,
         mod_options/1,
         mod_doc/0,
         create_message/1]).

start(_Host, _Opts) ->
    ?INFO_MSG("mod_tinvito_offline loading", []),
    inets:start(),
    ?INFO_MSG("HTTP client started", []),
    % URL = gen_mod:get_opt(url, _Opts),
    ejabberd_hooks:add(offline_message_hook, _Host, ?MODULE, create_message, 50),
    ok.

stop(_Host) ->
    ?INFO_MSG("stopping mod_http_offline", []),
    ejabberd_hooks:delete(offline_message_hook, _Host, ?MODULE, create_message, 50).

depends(_Host, _Opts) ->
    [].

%% Module option type checks
%% TODO: Find better way to ensure if parameter is string
mod_opt_type(url) ->
    %% url to call on offline message
    % fun(S) -> iolist_to_binary(S) end, list_to_binary("");
    fun(I) -> I end;
mod_opt_type(secret) ->
    %% url to call on offline message
    % fun(S) -> iolist_to_binary(S) end, list_to_binary("");
    fun(I) -> I end;
mod_opt_type(_) ->
    %% known parameters
    [url, secret].

mod_options(_Host) ->
    [{url, "http://localhost"},
     {secret, ""}].

mod_doc() ->
    #{desc =>
          ?T("This is an example module.")}.

%% Implementation of handlers
-spec create_message({any(), message()}) -> {any(), message()}.
create_message({_Action, #message{from = From, to = To, type = Type, body = Body, id = MessageId} = Packet} = Acc) ->
    LServer = To#jid.lserver,
    FromJid = io_lib:format("~s@~s", [From#jid.luser, From#jid.lserver]),
    ToJid = io_lib:format("~s@~s", [To#jid.luser, To#jid.lserver]),

    URL = parse_string(gen_mod:get_module_opt(LServer, ?MODULE, url)),
    SECRET = parse_string(gen_mod:get_module_opt(LServer, ?MODULE, secret)),

    T = io_lib:format("~s", [Type]),
    S = equal(T, "chat"),
    if (S == true) and (Body /= []) ->
        ?INFO_MSG("Sending http message \"~s\" from \"~s\" to \"~s\"", [MessageId, FromJid, ToJid]),

        [{text, _, BodyText}] = Body,

		Headers = [{"X-EJABBERD-HTTP-SECRET", SECRET}],
        ContentType = "application/json",
        JsonBody = "{"
            ++ "\"from\": \""
            ++ FromJid
            ++ "\", \"to\": \""
            ++ ToJid
            ++ "\", \"body\": \""
            ++ parse_string(BodyText)
            ++ "\"}",
        ?INFO_MSG(JsonBody, []),
        HTTPOptions = [],
        Options = [],
        httpc:request(post, {URL, Headers, ContentType, list_to_binary(JsonBody)}, HTTPOptions, Options);
	true ->
        % Do nothing if message is not chat
        ok
    end.

% Converts variable to basic string type
parse_string(Input) ->
    R = lists:flatten(io_lib:format("~p", [Input])),
    case string:equal(R, "<<>>") of
        true ->
            "";
        false ->
            string:substr(R, 4, string:len(R) - 6)
    end.
