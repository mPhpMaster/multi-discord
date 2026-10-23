// ============================================================
//  Discord Multi - macOS window (JavaScript for Automation + Cocoa)
//  Runs from discord-multi.sh:  osascript -l JavaScript discord-multi-mac.js /path/to/discord-multi.sh
//  or as "Discord Multi.app" (built by installer/build-mac-app.sh).
//  Every action calls discord-multi.sh, so the window and the command line always agree.
// ============================================================

ObjC.import('Cocoa');

var SCRIPT = '';          // path of discord-multi.sh
var rows = [];            // [{ name, running, startup }]
var rowsKey = '';
var app, win, table, statusLabel, nameField, hintLabel, btnStop, chkStartup, controller, source, timer;
var actionButtons = [];   // need a selected profile

// ---------------------------------------------------------------- shell

// Run discord-multi.sh with arguments; returns { ok, text }
function sh(args) {
    var task = $.NSTask.alloc.init;
    task.launchPath = '/bin/bash';
    task.arguments = $([SCRIPT].concat(args));
    var pipe = $.NSPipe.pipe;
    task.standardOutput = pipe;
    task.standardError = pipe;
    task.standardInput = $.NSFileHandle.fileHandleWithNullDevice;
    task.launch;
    var data = pipe.fileHandleForReading.readDataToEndOfFile;
    task.waitUntilExit;
    var text = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js || '';
    return { ok: task.terminationStatus === 0, text: text.replace(/\s+$/, '') };
}

// Show the error of a failed command
function check(r) {
    if (!r.ok) message(r.text.replace(/^Error: /, '') || 'Something went wrong.');
    return r.ok;
}

// ---------------------------------------------------------------- dialogs

function makeAlert(text) {
    var a = $.NSAlert.alloc.init;
    a.messageText = $('Discord Multi');
    a.informativeText = $(text);
    return a;
}

function message(text) {
    var a = makeAlert(text);
    a.addButtonWithTitle($('OK'));
    a.runModal;
}

function confirm(text, okTitle) {
    var a = makeAlert(text);
    a.alertStyle = 2;   // warning
    a.addButtonWithTitle($(okTitle));
    a.addButtonWithTitle($('Cancel'));
    return a.runModal === 1000;   // first button
}

// Text input; returns the trimmed text or null when cancelled
function ask(text, value) {
    var a = makeAlert(text);
    a.addButtonWithTitle($('OK'));
    a.addButtonWithTitle($('Cancel'));
    var field = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 260, 24));
    field.stringValue = $(value || '');
    a.accessoryView = field;
    a.window.initialFirstResponder = field;
    if (a.runModal !== 1000) return null;
    return field.stringValue.js.trim();
}

// ---------------------------------------------------------------- state

function selectedName() {
    var i = table.selectedRow;
    return (i >= 0 && i < rows.length) ? rows[i].name : null;
}

function needSelected() {
    var n = selectedName();
    if (!n) message('Select a profile from the list first.');
    return n;
}

function selectName(name) {
    for (var i = 0; i < rows.length; i++) {
        if (rows[i].name === name) {
            table.selectRowIndexesByExtendingSelection($.NSIndexSet.indexSetWithIndex(i), false);
            table.scrollRowToVisible(i);
            return;
        }
    }
}

function refresh() {
    var r = sh(['status']);
    if (!r.ok) return;
    var key = r.text;
    if (key !== rowsKey) {
        var keep = selectedName();
        rowsKey = key;
        rows = key ? key.split('\n').map(function (line) {
            var p = line.split('\t');
            return { name: p[0], running: p[1] === '1', startup: p[2] === '1' };
        }) : [];
        table.reloadData;
        if (keep) selectName(keep);
        if (table.selectedRow < 0 && rows.length) selectName(rows[0].name);
    }
    updateControls();
}

function updateControls() {
    var i = table.selectedRow;
    var row = (i >= 0 && i < rows.length) ? rows[i] : null;
    actionButtons.forEach(function (b) { b.enabled = !!row; });
    btnStop.enabled = !!(row && row.running);
    chkStartup.enabled = !!row;
    chkStartup.state = (row && row.startup) ? 1 : 0;
    if (!row) {
        statusLabel.stringValue = $(rows.length ? '' : 'No profiles yet. Add one below.');
        statusLabel.textColor = $.NSColor.secondaryLabelColor;
    } else if (row.running) {
        statusLabel.stringValue = $('Status: Running');
        statusLabel.textColor = $.NSColor.systemGreenColor;
    } else {
        statusLabel.stringValue = $('Status: Not running');
        statusLabel.textColor = $.NSColor.secondaryLabelColor;
    }
}

// ---------------------------------------------------------------- actions

var actions = {
    launch: function () {
        var n = needSelected(); if (!n) return;
        if (check(sh(['launch', n]))) setTimeout(refresh, 1500);
    },
    stop: function () {
        var n = needSelected(); if (!n) return;
        check(sh(['stop', n]));
        refresh();
    },
    launchAll: function () {
        if (!rows.length) { message('No profiles yet.'); return; }
        for (var i = 0; i < rows.length; i++) {
            if (!check(sh(['launch', rows[i].name]))) break;   // e.g. Discord is not installed
        }
        setTimeout(refresh, 1500);
    },
    shortcut: function () {
        var n = needSelected(); if (!n) return;
        if (check(sh(['shortcut', n]))) message('A launcher for "' + n + '" was added to your Desktop.');
    },
    folder: function () { sh(['folder']); },
    rename: function () {
        var old = needSelected(); if (!old) return;
        var n = ask('New name for "' + old + '":', old);
        if (!n || n === old) return;
        if (check(sh(['rename', old, n]))) { refresh(); selectName(n); updateControls(); }
    },
    remove: function () {
        var n = needSelected(); if (!n) return;
        if (!confirm('Delete profile "' + n + '" and all its data?\n(Close its Discord window first.)', 'Delete')) return;
        if (check(sh(['remove', n]))) refresh();
    },
    toggleStartup: function () {
        var i = table.selectedRow;
        if (i < 0 || i >= rows.length) return;
        // Flip the saved setting (the checkbox is redrawn from it below)
        var r = sh(['startup', rows[i].name, rows[i].startup ? 'off' : 'on']);
        debug('startup ' + rows[i].name + ': ' + r.text);
        check(r);
        rowsKey = '';   // force a reload of the flags
        refresh();
    },
    add: function () {
        var n = nameField.stringValue.js.trim();
        if (!n) { message('Enter a name for the profile.'); return; }
        if (check(sh(['add', n]))) {
            nameField.stringValue = $('');
            refresh();
            selectName(n);
            updateControls();
        }
    },
    about: function () { message(sh(['about']).text); }
};

// One-shot delayed call on the main run loop
var pending = [];
function setTimeout(fn, ms) {
    pending.push(fn);
    controller.performSelectorWithObjectAfterDelay('runPending:', $(), ms / 1000);
}

// ---------------------------------------------------------------- Objective-C glue

// A JavaScript error inside a Cocoa callback would crash the app: log it instead
function safe(fn, fallback) {
    return function () {
        try {
            return fn.apply(null, arguments);
        } catch (e) {
            console.log('Discord Multi: ' + e);
            return fallback;
        }
    };
}

function action(fn) { return { types: ['void', ['id']], implementation: safe(fn) }; }

ObjC.registerSubclass({
    name: 'DMController',
    superclass: 'NSObject',
    methods: {
        'launch:':          action(function () { actions.launch(); }),
        'stop:':            action(function () { actions.stop(); }),
        'launchAll:':       action(function () { actions.launchAll(); }),
        'shortcut:':        action(function () { actions.shortcut(); }),
        'folder:':          action(function () { actions.folder(); }),
        'rename:':          action(function () { actions.rename(); }),
        'remove:':          action(function () { actions.remove(); }),
        'toggleStartup:':   action(function () { actions.toggleStartup(); }),
        'add:':             action(function () { actions.add(); }),
        'about:':           action(function () { actions.about(); }),
        'tick:':            action(function () { refresh(); }),
        'runPending:':      action(function () { var f = pending.shift(); if (f) f(); }),
        'windowWillClose:': action(function () { $.NSApp.terminate($()); })
    }
});

ObjC.registerSubclass({
    name: 'DMTableSource',
    superclass: 'NSObject',
    protocols: ['NSTableViewDataSource', 'NSTableViewDelegate'],
    methods: {
        'numberOfRowsInTableView:': {
            types: ['long', ['id']],
            implementation: safe(function () { return rows.length; }, 0)
        },
        'tableView:objectValueForTableColumn:row:': {
            types: ['id', ['id', 'id', 'long']],
            implementation: safe(function (tv, col, i) {
                var row = rows[i];
                if (!row) return $('');
                return $(col.identifier.js === 'dot' ? '●' : row.name);
            }, $(''))
        },
        // Green dot = running, gray = not running
        'tableView:willDisplayCell:forTableColumn:row:': {
            types: ['void', ['id', 'id', 'id', 'long']],
            implementation: safe(function (tv, cell, col, i) {
                if (col.identifier.js !== 'dot') return;
                var row = rows[i];
                cell.textColor = (row && row.running) ? $.NSColor.systemGreenColor : $.NSColor.tertiaryLabelColor;
            })
        },
        'tableViewSelectionDidChange:': {
            types: ['void', ['id']],
            implementation: safe(function () { updateControls(); })
        }
    }
});

// ---------------------------------------------------------------- window

function label(text, x, y, w, h, size) {
    var l = $.NSTextField.labelWithString($(text));
    l.frame = $.NSMakeRect(x, y, w, h);
    if (size) l.font = $.NSFont.systemFontOfSize(size);
    win.contentView.addSubview(l);
    return l;
}

function button(title, action, x, y, w) {
    var b = $.NSButton.alloc.initWithFrame($.NSMakeRect(x, y, w, 32));
    b.title = $(title);
    b.bezelStyle = 1;   // rounded
    b.target = controller;
    b.action = action;
    win.contentView.addSubview(b);
    return b;
}

function buildMenu(appName) {
    var bar = $.NSMenu.alloc.init;
    var appItem = $.NSMenuItem.alloc.init;
    bar.addItem(appItem);
    var appMenu = $.NSMenu.alloc.init;
    appMenu.addItem($.NSMenuItem.alloc.initWithTitleActionKeyEquivalent($('About ' + appName), 'about:', $('')));
    appMenu.itemAtIndex(0).target = controller;
    appMenu.addItem($.NSMenuItem.separatorItem);
    appMenu.addItem($.NSMenuItem.alloc.initWithTitleActionKeyEquivalent($('Quit ' + appName), 'terminate:', $('q')));
    appItem.submenu = appMenu;
    // Edit menu, so copy / paste work in the name field
    var editItem = $.NSMenuItem.alloc.init;
    bar.addItem(editItem);
    var edit = $.NSMenu.alloc.initWithTitle($('Edit'));
    [['Cut', 'cut:', 'x'], ['Copy', 'copy:', 'c'], ['Paste', 'paste:', 'v'], ['Select All', 'selectAll:', 'a']].forEach(function (m) {
        edit.addItem($.NSMenuItem.alloc.initWithTitleActionKeyEquivalent($(m[0]), m[1], $(m[2])));
    });
    editItem.submenu = edit;
    app.mainMenu = bar;
}

function buildWindow(version) {
    var W = 460, H = 450;
    win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
        $.NSMakeRect(0, 0, W, H), 1 | 2 | 4 /* titled, closable, miniaturizable */, 2 /* buffered */, false);
    win.title = $('Discord Multi ' + version + ' - Multiple Accounts');
    win.releasedWhenClosed = false;
    win.delegate = controller;

    label('Profiles (each one = a separate account):', 15, H - 34, 300, 20);

    // Profile list: a dot (running or not) and the name
    table = $.NSTableView.alloc.initWithFrame($.NSMakeRect(0, 0, 248, 290));
    var dot = $.NSTableColumn.alloc.initWithIdentifier($('dot'));
    dot.width = 18;
    dot.editable = false;
    table.addTableColumn(dot);
    var nameCol = $.NSTableColumn.alloc.initWithIdentifier($('name'));
    nameCol.width = 215;
    nameCol.editable = false;
    table.addTableColumn(nameCol);
    table.headerView = $();
    table.rowHeight = 22;
    table.dataSource = source;
    table.delegate = source;
    table.target = controller;
    table.doubleAction = 'launch:';
    var scroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(15, H - 334, 250, 292));
    scroll.documentView = table;
    scroll.hasVerticalScroller = true;
    scroll.borderType = 2;   // bezel
    win.contentView.addSubview(scroll);

    statusLabel = label('', 15, H - 360, 250, 20);

    // Right column
    var x = 280, w = 165, y = H - 76;
    var btnRun = button('Launch', 'launch:', x, y, 83);
    btnStop = button('Stop', 'stop:', x + 82, y, 83);
    y -= 36; button('Launch All', 'launchAll:', x, y, w);
    y -= 36; var btnLnk = button('Desktop Shortcut', 'shortcut:', x, y, w);
    y -= 36; button('Open Folder', 'folder:', x, y, w);
    y -= 36; var btnRename = button('Rename', 'rename:', x, y, w);
    y -= 36; var btnDel = button('Delete', 'remove:', x, y, w);
    y -= 34;
    chkStartup = $.NSButton.alloc.initWithFrame($.NSMakeRect(x + 6, y, w, 24));
    chkStartup.buttonType = 3;   // checkbox
    chkStartup.title = $('Start at login');
    chkStartup.target = controller;
    chkStartup.action = 'toggleStartup:';
    win.contentView.addSubview(chkStartup);
    y -= 38; button('About', 'about:', x, y, w);
    actionButtons = [btnRun, btnLnk, btnRename, btnDel];

    // Add a profile
    nameField = $.NSTextField.alloc.initWithFrame($.NSMakeRect(15, 52, 250, 24));
    nameField.placeholderString = $('Profile name, e.g. Work');
    nameField.target = controller;
    nameField.action = 'add:';   // Return key adds
    win.contentView.addSubview(nameField);
    button('+  Add Account', 'add:', x, 48, w);

    hintLabel = label('Type a name and click Add. Double-click a name to launch.', 15, 18, 430, 18, 11);
    hintLabel.textColor = $.NSColor.secondaryLabelColor;

    win.center;
}

// Read the version from discord-multi.sh (VERSION="x.y.z")
function scriptVersion() {
    var r = sh(['version']);
    return r.ok ? r.text : '';
}

// In the app bundle: run a copy of the script from Application Support, so start-at-login and
// Desktop launchers keep working when the app is moved (or run from a temporary location)
function stableScript() {
    var fm = $.NSFileManager.defaultManager;
    var bundled = $.NSBundle.mainBundle.pathForResourceOfType($('discord-multi'), $('sh'));
    if (!bundled || !bundled.js) return '';
    var dir = $.NSHomeDirectory().js + '/Library/Application Support/Discord Multi';
    fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError($(dir), true, $(), $());
    ['discord-multi.sh', 'discord-multi-mac.js'].forEach(function (f) {
        var src = bundled.js.replace(/[^/]+$/, f), dest = dir + '/' + f;
        if (!fm.fileExistsAtPath($(src))) return;
        fm.removeItemAtPathError($(dest), $());
        fm.copyItemAtPathToPathError($(src), $(dest), $());
    });
    return dir + '/discord-multi.sh';
}

function run(argv) {
    try {
        start(argv);
    } catch (e) {
        console.log('Discord Multi: ' + e + (e && e.stack ? '\n' + e.stack : ''));
        throw e;
    }
}

function debug(text) {
    if ($.NSProcessInfo.processInfo.environment.objectForKey($('DISCORD_MULTI_DEBUG')).js) console.log(text);
}

function start(argv) {
    var fromApp = !(argv && argv.length);
    debug('start: fromApp=' + fromApp + ' argv=' + JSON.stringify(argv));
    SCRIPT = fromApp ? stableScript() : argv[0];
    app = $.NSApplication.sharedApplication;
    controller = $.DMController.alloc.init;
    source = $.DMTableSource.alloc.init;
    if (!SCRIPT) { message('discord-multi.sh was not found.'); $.NSApp.terminate($()); return; }

    if (!fromApp) {
        // Started from Terminal: become a normal app with a Dock icon and a menu
        app.setActivationPolicy(0);   // regular
        buildMenu('Discord Multi');
        var icon = $.NSImage.alloc.initWithContentsOfFile($(SCRIPT.replace(/[^/]+$/, 'assets/logo.png')));
        if (icon && !icon.isNil()) app.applicationIconImage = icon;
    }

    debug('script: ' + SCRIPT);
    buildWindow(scriptVersion());
    debug('window built');
    refresh();
    debug('rows: ' + JSON.stringify(rows));
    timer = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(2, controller, 'tick:', $(), true);
    win.makeKeyAndOrderFront($());
    app.activateIgnoringOtherApps(true);
    // The app bundle (stay-open applet) already runs its event loop; from Terminal start one
    debug('showing window');
    if (!fromApp) app.run;
}
