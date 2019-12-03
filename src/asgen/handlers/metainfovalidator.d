/*
 * Copyright (C) 2016 Matthias Klumpp <matthias@tenstral.net>
 *
 * Licensed under the GNU Lesser General Public License Version 3
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the license, or
 * (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this software.  If not, see <http://www.gnu.org/licenses/>.
 */

module asgen.handlers.metainfovalidator;

import std.path : baseName;
import std.uni : toLower;
import std.string : format;
import std.stdio;
import std.typecons : scoped;

import appstream.Validator;
import appstream.ValidatorIssue;
import appstream.Component;
import glib.ListG;
import gobject.ObjectG;

import asgen.result;
import asgen.utils;


void validateMetaInfoFile (GeneratorResult res, Component cpt, string data)
{
    auto validator = scoped!Validator ();
    validator.setCheckUrls (false); // don't check web URLs for validity

    try {
        validator.validateData (data);
    } catch (Exception e) {
        res.addHint (cpt.getId (), "metainfo-validation-issue", "The file could not be validated due to an error: " ~ e.msg);
        return;
    }

    auto issueList = validator.getIssues ();
    for (ListG l = issueList; l !is null; l = l.next) {
        auto issue = ObjectG.getDObject!ValidatorIssue (cast (typeof(ValidatorIssue.tupleof[0])) l.data);

        // we have a special hint tag for legacy metadata
        if (issue.getKind () == IssueKind.LEGACY) {
            res.addHint (cpt.getId (), "ancient-metadata");
            continue;
        }

        immutable severity = issue.getSeverity ();
        auto msg = issue.getMessage();

        // we ignore pedantic hints by default and don't store or display them
        if (severity == IssueSeverity.PEDANTIC)
            continue;

        if (severity == IssueSeverity.INFO)
            res.addHint (cpt.getId (), "metainfo-validation-hint", msg);
        else
            res.addHint (cpt.getId (), "metainfo-validation-issue", msg);
    }
}
