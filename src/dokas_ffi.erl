%% Erlang stubs for the browser bindings declared in dokas/ffi.gleam.
%%
%% These are never called in practice: the application only runs in the browser.
%% They exist so the project can be compiled and tested on the Erlang target
%% (for example when running `gleam test`).
-module(dokas_ffi).

-export([local_storage_get/1, local_storage_set/2]).

-spec local_storage_get(binary()) -> binary().
local_storage_get(_Key) -> <<>>.

-spec local_storage_set(binary(), binary()) -> nil.
local_storage_set(_Key, _Value) -> nil.
