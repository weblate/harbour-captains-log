/*
 * This file is part of Captain's Log.
 *
 * SPDX-FileCopyrightText: 2020 Gabriel Berkigt
 * SPDX-FileCopyrightText: 2020-2023 Mirian Margiani
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Captain's Log is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * Captain's Log is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Dialog {
    id: page
    allowedOrientations: Orientation.All // effective value restricted by ApplicationWindow.allowedOrientations

    onStatusChanged: {
        // make sure the date is always correct, even if the page has been
        // on the stack for a long time
        if (status !== PageStatus.Activating) return;
        currentDate = new Date().toLocaleString(Qt.locale(), fullDateTimeFormat);
        dbCurrentDate = new Date().toLocaleString(Qt.locale(), dbDateFormat);

        if (!editing) {
            moodCombo.clicked(null) // open mood menu
        }
    }

    property string currentDate: new Date().toLocaleString(Qt.locale(), fullDateTimeFormat);
    property string dbCurrentDate: Qt.formatDateTime(new Date(), dbDateFormat)
    property bool editing: rowid > -1

    property string createDate: dbCurrentDate
    property string modifyDate: ""
    property alias title: titleField.text
    property alias entry: entryArea.text
    property alias hashtags: hashtagField.text
    property alias mood: moodMenu.selectedIndex
    property string createTz: ""
    property string modifyTz: ""
    property int rowid: -1
    property int index: -1
    property var model: null

    onAccepted: {
        var mood = page.mood
        var title_text = titleField.text.trim()
        // regular expression to kick out all newline chars in preview
        var preview = entryArea.text.substring(0, 150).replace(/\r?\n|\r/g, " ").trim()
        var entry = entryArea.text.trim()
        var hashs = hashtagField.text.trim()

        if (editing) {
            updateEntry(model, index, createDate, createTz, mood, title_text, preview, entry, hashs, rowid);
        } else {
            addEntry(dbCurrentDate, mood, title_text, preview, entry, hashs);
        }
    }

    onDone: {
        if (result != DialogResult.Rejected && result != DialogResult.None) {
            return
        }

        if (title == "" && entry == "" && hashtags == "") {
            return
        }

        appWindow._currentlyEditedEntry.createDate = createDate
        appWindow._currentlyEditedEntry.modifyDate = modifyDate
        appWindow._currentlyEditedEntry.title      = title
        appWindow._currentlyEditedEntry.entry      = entry
        appWindow._currentlyEditedEntry.hashtags   = hashtags
        appWindow._currentlyEditedEntry.mood       = mood
        appWindow._currentlyEditedEntry.createTz   = createTz
        appWindow._currentlyEditedEntry.modifyTz   = modifyTz
        appWindow._currentlyEditedEntry.rowid      = rowid
        appWindow._currentlyEditedEntry.index      = index
        appWindow._currentlyEditedEntry.model      = model

        try {
            var page = pageStack.previousPage(page)
        } catch(error) {
            page = appWindow
        }

        if (editing) {
            remorseCancelWriting(page || appWindow, qsTr("Discarded all changes"))
        } else {
            remorseCancelWriting(page || appWindow, qsTr("Discarded the entry"))
        }
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge
        VerticalScrollDecorator { flickable: flick }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: editing ? qsTr("Edit Entry") : qsTr("New Entry")
                acceptText: qsTr("Save")
                cancelText: qsTr("Discard")
            }

            DateTimePickerCombo {
                label: qsTr("Date")
                date: createDate
                timeZone: createTz
                description: modifyDate !== "" ?
                                 qsTr("Last edited: %1").arg(formatDate(
                                     modifyDate, fullDateTimeFormat, modifyTz, qsTr("never"))) :
                                 ""
                onDateChanged: createDate = date

                // Changing the entry date is not allowed later because
                // it is too complicated to ensure entries are properly
                // sorted, due to timezones and the way entries are
                // stored in the database.
                // enabled: !editing

                // TODO enable with "!editing" once addenda are properly
                //      implemented:
                // - dates must not be in the future
                // - save with 'now' as modification date and 'selected date'
                //   as creation date
                // - mark as addendum in a new database column
                // - show the entry as the last entry of its day, regardless
                //   of the time, and highlight it as an addendum
                enabled: false
            }

            ComboBox {
                id: moodCombo
                value: moodTexts[mood]
                width: parent.width
                description: editing ? qsTr("How did you feel?") : qsTr("How do you feel?")
                label: qsTr("Your mood")

                menu: MoodMenu {
                    id: moodMenu
                    selectedIndex: 2
                    onClosed: if (!editing) entryArea.forceActiveFocus()
                }
            }

            TextField {
                id: titleField
                width: parent.width
                placeholderText: qsTr("Add a title")
                label: qsTr("Title")
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: {
                    entryArea.focus = true
                }
            }

            TextArea {
                id: entryArea
                width: parent.width
                placeholderText: editing ? qsTr("What do you want to say?") : qsTr("Entry...")
                label: qsTr("Entry")
                wrapMode: TextEdit.WordWrap
            }

            TextField {
                id: hashtagField
                width: parent.width
                placeholderText: qsTr("Hashtags")
                font.pixelSize: Theme.fontSizeExtraSmall
                label: qsTr("#Hashtags")
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: {
                    hashtagField.focus = false
                }
            }
        }
    }
}
