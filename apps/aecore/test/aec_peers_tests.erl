%%%=============================================================================
%%% @copyright (C) 2017, Aeternity Anstalt
%%% @doc
%%%   Unit tests for the aec_peers module
%%% @end
%%%=============================================================================
-module(aec_peers_tests).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").
-include("peers.hrl").

all_test_() ->
    {setup,
     fun setup/0,
     fun teardown/1,
     [{"Add a peer by Uri",
       fun() ->
               ?assertEqual(ok, aec_peers:add("http://someone.somewhere:1337/v1"))
       end},
      {"Get a random peer (from list of 1)",
       fun() ->
               {Status, Peer} = aec_peers:get_random(),
               ?assertEqual(ok, Status),
               ?assertEqual("http://someone.somewhere:1337/v1/", Peer#peer.uri)
       end},
      {"Add a peer by object",
       fun() ->
               ?assertEqual(ok, aec_peers:add(#peer{uri="http://someonelse.somewhereelse:1337/v1", last_seen=123123}))
       end},
      {"Get info",
       fun() ->
               {Status, Peer} = aec_peers:info("http://someonelse.somewhereelse:1337/v1"),
               ?assertEqual(ok, Status),
               ?assertEqual(123123, Peer#peer.last_seen)
       end},
      {"All",
       fun() ->
               ?assertEqual(2, length(aec_peers:all()))
       end},
      {"Remove a peer",
       fun() ->
               ?assertEqual(ok, aec_peers:remove("http://someone.somewhere:1337/v1")),
               ?assertEqual(1, length(aec_peers:all()))
       end},
      {"Uri_from_ip_port",
       fun() ->
               ?assertEqual("http://123.123.123.123:1337/", aec_peers:uri_from_ip_port("123.123.123.123", 1337))
       end},
      {"Remove all",
       fun do_remove_all/0},
      {"Add peer",
       fun() ->
               ok = aec_peers:add("http://localhost:800", false),
               ["http://localhost:800/"] =
                   [aec_peers:uri(P) || P <- aec_peers:all()]
       end},
      {"Register source",
       fun() ->
               ok = aec_peers:register_source("http://somenode:800",
                                              "http://localhost:800"),
               {ok, P} = aec_peers:info("http://localhost:800"),
               "http://somenode:800/" = aec_peers:uri(P)
       end},
      {"Get random N",
       fun() ->
               do_remove_all(),
               Base = "http://localhost:",
               [ok = aec_peers:add(Base ++ integer_to_list(N))
                || N <- lists:seq(900,910)],
               L1 = aec_peers:get_random(5),
               5 = length(L1)
       end}

     ]
    }.

do_remove_all() ->
    [aec_peers:remove(P) || P <- aec_peers:all()],
    [] = aec_peers:all(),
    ok.


setup() ->
    crypto:start(),
    aec_peers:start_link().

teardown(_) ->
    crypto:stop().

-endif.
