/*
 * This file is part of Captain's Log.
 * SPDX-FileCopyrightText: 2023 Mirian Margiani
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0
import SortFilterProxyModel 0.2

// Requires appWindow.moodTexts

QtObject {
    id: root

    property bool matchAllMode: true
    property string text
    property int textMatchMode
    property date dateMin: new Date('0000-01-01')
    property date dateMax: new Date('9999-01-01')
    property int bookmark: Qt.PartiallyChecked
    property string hashtags
    property int moodMin: 0
    property int moodMax: appWindow.moodTexts.length - 1

    property bool enableLogging: false

    function _logChange(name) {
        if (!enableLogging) return
        console.log("search query changed:", name, "=", root[name])
    }

    onMatchAllModeChanged: _logChange("matchAllMode")
    onTextChanged: _logChange("text")
    onTextMatchModeChanged: _logChange("textMatchMode")
    onDateMinChanged: _logChange("dateMin")
    onDateMaxChanged: _logChange("dateMax")
    onBookmarkChanged: _logChange("bookmark")
    onHashtagsChanged: _logChange("hashtags")
    onMoodMinChanged: _logChange("moodMin")
    onMoodMaxChanged: _logChange("moodMax")
}
