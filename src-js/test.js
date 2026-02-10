var ganomede = require("../index");
var client = null;
var user = null;

var serverUrl = process.env.GANOMEDE_TEST_SERVER_URL;
var testUsername = process.env.GANOMEDE_TEST_USERNAME;
var testUsername2 = process.env.GANOMEDE_TEST_USERNAME2 || testUsername + "_p2";
if (!serverUrl) {
    console.error("Please specify your test server URL in GANOMEDE_TEST_SERVER_URL environment variable");
    process.exit(1);
}

function initialize(done) {
    client = ganomede.createClient(serverUrl, {
        registry: { enabled: true },
        users: { enabled: true },
        notifications: { enabled: true },
        invitations: { enabled: true },
        turngames: { enabled: true },
        games: {
            enabled: true,
            type: "triominos/v1"
        },
        virtualcurrency: { enabled: true }
    });
    client.initialize()
    .then(function initializeSuccess(res) {
        console.log("initialize success");
        // console.dir(client.registry.services);
        done();
    })
    .error(function initializeError(err) {
        console.error("initialize error");
        console.dir(err);
        process.exit(1);
    });
}

function login(done) {
    user = new ganomede.GanomedeUser({
        username: process.env.GANOMEDE_TEST_USERNAME,
        password: process.env.GANOMEDE_TEST_PASSWORD,
        token:    process.env.GANOMEDE_TEST_TOKEN
    });
    if (!user.username || !(user.password || user.token)) {
        console.error("Please specify your test username and (password|token) using environment variables:");
        console.error(" - GANOMEDE_TEST_USERNAME");
        console.error(" - GANOMEDE_TEST_PASSWORD");
        console.error(" - GANOMEDE_TEST_TOKEN");
        process.exit(1);
    }
    var method = "login";
    if (user.token) {
        client.users.me.token = user.token;
        method = "fetch";
    }
    client.users[method](user)
    .then(function loginSuccess(res) {
        console.log("login success");
        user = client.users.me;
        // console.dir(user);
        done();
    })
    .error(function loginError(err) {
        console.error("login error");
        console.dir(err);
        process.exit(1);
    });
}

function profile(done) {
    client.users.fetch(user)
    .then(function profileSuccess() {
        console.log("profile success");
        console.dir(user);
        done();
    })
    .error(function profileError(err) {
        console.error("profile error");
        console.dir(err);
        process.exit(1);
    });
}

function metadata(done) {
    ganomede.async.Waterfall.run([
        function() {
            console.log("readMetadata unknown");
            return client.users.loadMetadata("invalid-key")
            .then(function(result) {
                if (result.value != null) {
                    console.error("metadata error (invalid-key)");
                    console.dir(result);
                    process.exit(1);
                }
            });
        },
        function() {
            console.log("saveMetadata val1");
            return client.users.saveMetadata("my-key", "val1")
            .then(console.dir);
        },
        function() {
            console.log("readMetadata val1");
            return client.users.loadMetadata("my-key")
            .then(function(result) {
                if (result.value != "val1") {
                    console.error("metadata error (val1)");
                    console.dir(result);
                    process.exit(1);
                }
            });
        },
        function() {
            console.log("saveMetadata val2");
            return client.users.saveMetadata("my-key", "val2")
            .then(console.dir);
        },
        function() {
            console.log("readMetadata val2");
            return client.users.loadMetadata("my-key")
            .then(function(result) {
                if (result.value != "val2") {
                    console.error("metadata error (val2)");
                    console.dir(result);
                    process.exit(1);
                }
            });
        }
    ])
    .error(function metadataError(err) {
        console.error("metadata error");
        console.dir(err);
        process.exit(1);
    })
    .then(function() {
        console.log("metadata success");
        done();
    });
}

function refreshInvitations(done) {
    client.invitations.refreshArray()
    .then(done)
    .error(function(err) {
        console.error("invitations error (refresh)");
        console.dir(err);
        process.exit(1);
    });
}

function invitations(done) {

    console.log("invitations");
    console.dir(client.invitations.asArray());

    var invitation = new ganomede.models.GanomedeInvitation({
        type: "triominos/v1",
        to: "joe",
        gameId: "dummy"
    });
    client.invitations.add(invitation)
    .then(function() {
        console.log("invitation success");
        console.dir(client.invitations.asArray());
        client.invitations.cancel(invitation)
        .then(done)
        .error(function cancelError(err) {
            console.error("invitation cancel error");
            console.dir(err);
            process.exit(1);
        });
    })
    .error(function invitationError(err) {
        console.error("invitation error");
        console.dir(err);
        process.exit(1);
    });
}

function virtualcurrencyProducts(done) {
    console.log("virtualcurrency.products");
    client.virtualcurrency.refreshProductsArray()
    .then(function() {
        if (client.virtualcurrency.products.asArray().length == 0) {
            console.error("virtualcurrency.products failed to load products.");
            process.exit(1);
        }
        console.log("virtualcurrency.products success");
        done();
    })
    .error(function productsError(err) {
        console.error("virtualcurrency.products error");
        console.dir(err);
        process.exit(1);
    });
}

function virtualcurrencyBalance(done) {
    console.log("virtualcurrency.balance");
    client.virtualcurrency.refreshBalances(["test-currency-1"])
    .then(function() {
        console.dir(client.virtualcurrency.balances.get("test-currency-1"));
        if (client.virtualcurrency.balances.get("test-currency-1").count !== 0) {
            console.error("virtualcurrency.balance failed to load.");
            process.exit(1);
        }
        done();
    })
    .error(function balanceError(err) {
        console.error("virtualcurrency.balance error");
        console.dir(err);
        process.exit(1);
    });
}

function virtualcurrencyPurchases(done) {
    console.log("virtualcurrency.purchases");
    client.virtualcurrency.refreshPurchasesArray(["triominos-gold", "triominos-silver"])
    .then(function() {
        if (client.virtualcurrency.purchases.asArray().length == 0) {
            console.error("virtualcurrency.purchases failed to load purchases.");
            process.exit(1);
        }
        console.log("virtualcurrency.purchases success");
        done();
    })
    .error(function purchasesError(err) {
        console.error("virtualcurrency.purchases error");
        console.dir(err);
        process.exit(1);
    });
}

function notifications(done) {
    console.log("notification");
    var rnd = "" + Math.random();
    var nCalls = 0;
    client.notifications.listenTo("test/v1", function(event) {
        if (event.notification.data.rnd !== rnd) {
            // old message
            return;
        }
        nCalls += 1;
        if (nCalls > 1) {
            console.error("notification error (called too many times)");
            process.exit(1);
        }
        console.log("notification success");
        if (event.notification.data.iamtrue !== true
            || event.notification.type !== "success"
            || event.notification.from !== "test/v1") {
            console.error("notification error");
            process.exit(1);
        }
        done();
    });
    var n = new ganomede.GanomedeNotification({
        from: "test/v1",
        to: process.env.GANOMEDE_TEST_USERNAME,
        type: "success",
        data: {
            iamtrue: true,
            rnd:rnd
        }
    });
    client.notifications.apiSecret = process.env.API_SECRET;
    console.log("send notification");
    setTimeout(function() {
        client.notifications.send(n)
        .error(function(err) {
            console.error("notifications error (sending notif)");
            console.dir(err);
            process.exit(1);
        });
    }, 100);
}

function refreshGames(done) {
    client.games.refreshArray()
    .then(done)
    .error(function(err) {
        console.error("games error (refresh)");
        console.dir(err);
        process.exit(1);
    });
}

function leaveAllGames(done) {
    var games = client.games.asArray();
    console.log("leaveAllGames (" + games.length + ")");
    var numDone = 0;
    var oneDone = function() {
        numDone += 1;
        if (numDone == games.length)
            done();
        if (numDone > games.length) {
            console.error("games error (done callback called too many times)");
            process.exit(1);
        }
    };
    for (var i = 0; i < games.length; ++i) {
        client.games.leave(games[i])
        .then(oneDone)
        .error(function(err) {
            console.error("games error (leave)");
            console.dir(err);
            process.exit(1);
        });
    }
    if (games.length == 0) {
        done();
    }
}

var game2p;
function createGame2P(done) {
    var a0 = client.games.asArray();
    if (a0.length != 0) {
        console.error("no active games at startup");
        process.exit(1);
    }
    var g = new ganomede.models.GanomedeGame({
        type: client.options.games.type,
        players: [ testUsername, testUsername2 ]
    });
    console.log("create 2 players game");
    client.games.add(g)
    .then(function(res) {
        var a1 = client.games.asArray();
        if (a1.length != 0) {
            console.error("still no active games");
            process.exit(1);
        }
        if (!g.id) {
            console.log("game id should have been generated");
            process.exit(1);
        }
        game2p = g;
        done();
    })
    .error(function(err) {
        console.error("games error (addGame)");
        console.dir(err);
        process.exit(1);
    });
}

function createTurnGame2P(done) {
    var g = new ganomede.models.GanomedeTurnGame().fromGame(game2p);
    console.log("create 2 players turngame");
    client.turngames.add(g)
    .then(function(res) {
        if (g.turn != game2p.players[0] && g.turn != game2p.players[1]) {
            console.log("it should be to one of the players to play");
            console.log(g.turn, game2p.players);
            process.exit(1);
        }
        /*if (g.gameData.stock.pieces.length != 33) {
            console.log("stock should have 33 pieces (has " + g.gameData.stock.pieces.length + ")");
            process.exit(1);
        }*/
        done();
    })
    .error(function(err) {
        console.error("turngames error (addGame)");
        console.dir(err);
        process.exit(1);
    });
}

function createGame1P(done) {
    var a0 = client.games.asArray();
    if (a0.length != 0) {
        console.error("no active games at startup");
        process.exit(1);
    }
    var g = new ganomede.models.GanomedeGame({
        type: client.options.games.type,
        players: [ testUsername ]
    });
    console.log("create 1 player game");
    client.games.add(g)
    .then(function(res) {
        var a1 = client.games.asArray();
        if (a1.length != 1) {
            console.error("there should be 1 active games");
            console.dir(a1);
            process.exit(1);
        }
        if (!g.id) {
            console.log("game id should have been generated");
            process.exit(1);
        }
        done();
    })
    .error(function(err) {
        console.error("games error (addGame)");
        console.dir(err);
        process.exit(1);
    });
}

function inviteTurngameHelperDuplicate(done) {
    console.log("purposely failed invite to turngame");
    var game = new ganomede.models.GanomedeGame({
        type: client.options.games.type,
        players: [ testUsername, testUsername2 ]
    });
    var turngameInvitation = new ganomede.helpers.GanomedeTurnGameInvitation(client);
    turngameInvitation.send(game)
    .then(function(res) {
        console.error("sending duplicate invitation should fail (inviteTurngameHelper)");
        process.exit(1);
    })
    .error(function(err) {
        done();
    });
}

function inviteTurngameHelper(done) {
    console.log("invite to turngame");
    var game = new ganomede.models.GanomedeGame({
        type: client.options.games.type,
        players: [ testUsername, "testuserx" ]
    });
    client.invitations.cancel(new ganomede.models.GanomedeInvitation({
        id: 'd7bb8f947ac624dc43d36943a6550518',
        type: client.options.games.type,
        from: testUsername,
        to: "testuserx"
    }))
    .always(function() {
        // ganomede.net.Ajax.verbose = true;
        var turngameInvitation = new ganomede.helpers.GanomedeTurnGameInvitation(client);
        turngameInvitation.send(game)
        .then(function(res) {
            if (!turngameInvitation.id) {
                console.error("turngameInvitation should have an id");
                process.exit(1);
            }
            client.invitations.cancel(turngameInvitation)
            .then(done)
            .error(function(err) {
                console.error("cancel invitation should not fail (inviteTurngameHelper)");
                console.dir(err);
                process.exit(1);
            });
        })
        .error(function(err) {
            console.error("sending invitation should not fail (inviteTurngameHelper)");
            console.dir(err);
            process.exit(1);
        });
    });
}

function logout(done) {
    console.log("logout");
    client.users.logout();
    done();
}

function done() {
    console.log("All good! We're done.");
    setTimeout(process.exit.bind(process, 0), 1000);
}

//ganomede.net.Ajax.verbose = true;

var testStrategyChain = require("./testStrategyChain");

initialize(
    testStrategyChain.bind(null,
    login.bind(null,
    virtualcurrencyProducts.bind(null,
    virtualcurrencyBalance.bind(null,
    virtualcurrencyPurchases.bind(null,
    profile.bind(null,
    metadata.bind(null,
    refreshInvitations.bind(null,
    invitations.bind(null,
    notifications.bind(null,
    notifications.bind(null,
    refreshGames.bind(null,
    leaveAllGames.bind(null,
    createGame2P.bind(null,
    createTurnGame2P.bind(null,
    createGame1P.bind(null,
    inviteTurngameHelperDuplicate.bind(null,
    inviteTurngameHelper.bind(null,
    leaveAllGames.bind(null,
    logout.bind(null,
    done
)))))))))))))))))))));

setTimeout(function() {
    console.error("test timeout");
    process.exit(1);
}, 60000);
