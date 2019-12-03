/*
 * Copyright (C) 2016-2017 Matthias Klumpp <matthias@tenstral.net>
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

module asgen.backends.debian.debpkg;

import std.stdio;
import std.string;
import std.path;
import std.array : empty, appender;
import std.file : rmdirRecurse, mkdirRecurse;
static import std.file;

import asgen.config;
import asgen.zarchive;
import asgen.backends.interfaces;
import asgen.logging;
import asgen.utils : isRemote, downloadFile;


class DebPackage : Package
{
private:
    string pkgname;
    string pkgver;
    string pkgarch;
    string pkgmaintainer;
    string[string] desc;
    string[string] summ;
    GStreamer gstreamer;

    bool contentsRead;
    string[] contentsL;

    string tmpDir;
    string dataArchive;
    string controlArchive;

    string debFname;

public:
    final @property override string name () const { return pkgname; }
    final @property override string ver () const { return pkgver; }
    final @property override string arch () const { return pkgarch; }

    final @property override GStreamer gst () { return gstreamer; }
    final @property void gst (GStreamer gst) { gstreamer = gst; }

    final @property override const(string[string]) description () const { return desc; }
    final @property override const(string[string]) summary () const { return summ; }

    override final
    @property string filename () const {
        if (debFname.isRemote) {
            immutable path = buildNormalizedPath (tmpDir, debFname.baseName);
            synchronized (this) {
                downloadFile (debFname, path);
            }
            return path;
        }
        return debFname;
    }
    final @property void   filename (string fname) { debFname = fname; }

    override
    final @property string maintainer () const { return pkgmaintainer; }
    final @property void   maintainer (string maint) { pkgmaintainer = maint; }

    this (string pname, string pver, string parch)
    {
        pkgname = pname;
        pkgver = pver;
        pkgarch = parch;

        contentsRead = false;

        auto conf = Config.get ();
        tmpDir = buildPath (conf.getTmpDir (), format ("%s-%s_%s", name, ver, arch));
    }

    ~this ()
    {
        // FIXME: We can't properly clean up because we can't GC-allocate in a destructor (leads to crashes),
        // see if this is fixed in a future version of D, or simply don't use the GC in close ().
        // close ();
    }

    final void setDescription (string text, string locale)
    {
        desc[locale] = text;
    }

    final void setSummary (string text, string locale)
    {
        summ[locale] = text;
    }

    private auto openPayloadArchive ()
    {
        auto pa = new ArchiveDecompressor ();
        if (!dataArchive) {
            import std.regex;

            // extract the payload to a temporary location first
            pa.open (this.filename);
            mkdirRecurse (tmpDir);

            string[] files;
            try {
                files = pa.extractFilesByRegex (ctRegex!(r"data\.*"), tmpDir);
            } catch (Exception e) { throw e; }

            if (files.length == 0)
                return null;
            dataArchive = files[0];
        }

        pa.open (dataArchive);
        return pa;
    }

    protected final void extractPackage (const string dest = buildPath (tmpDir, name))
    {
        import std.file : exists;
        import std.regex : ctRegex;

        if (!dest.exists)
            mkdirRecurse (dest);

        auto pa = openPayloadArchive ();
        pa.extractArchive (dest);
    }

    private final auto openControlArchive ()
    {
        auto ca = new ArchiveDecompressor ();
        if (!controlArchive) {
            import std.regex;

            // extract the payload to a temporary location first
            ca.open (this.filename);
            mkdirRecurse (tmpDir);

            string[] files;
            try {
                files = ca.extractFilesByRegex (ctRegex!(r"control\.*"), tmpDir);
            } catch (Exception e) { throw e; }

            if (files.empty)
                return null;
            controlArchive = files[0];
        }

        ca.open (controlArchive);
        return ca;
    }

    override final
    const(ubyte)[] getFileData (string fname)
    {
        auto pa = openPayloadArchive ();
        return pa.readData (fname);
    }

    @property override final
    string[] contents ()
    {
        import std.utf;

        if (contentsRead)
            return contentsL;

        if (pkgname.endsWith ("icon-theme")) {
            // the md5sums file does not contain symbolic links - while that is okay-ish for regular
            // packages, it is not acceptable for icon themes, since those rely on symlinks to provide
            // aliases for certain icons. So, use the slow method for reading contents information here.

            auto pa = openPayloadArchive ();
            contentsL = pa.readContents ();
            contentsRead = true;

            return contentsL;
        }

        // use the md5sums file of the .deb control archive to determine
        // the contents of this package.
        // this is way faster than going through the payload directly, and
        // has the same accuracy.
        auto ca = openControlArchive ();
        const(ubyte)[] md5sumsData;
        try {
            md5sumsData = ca.readData ("./md5sums");
        } catch (Exception e) {
            logWarning ("Could not read md5sums file for package %s: %s", this.id, e.msg);
            return [];
        }

        auto md5sums = cast(string) md5sumsData;
        try {
            md5sums = md5sums.toUTF8;
        } catch (Exception e) {
            logError ("Could not decode md5sums file for package %s: %s", this.id, e.msg);
            return [];
        }

        auto contentsAppender = appender!(string[]);
        foreach (line; md5sums.splitLines ()) {
            auto parts = line.split ("  ");
            if (parts.length <= 0)
                continue;
            string c = join (parts[1..$], "  ");
            contentsAppender.put ("/" ~ c);
        }
        contentsL = contentsAppender.data;

        contentsRead = true;
        return contentsL;
    }

    override final
    void close ()
    {
        try {
            if (std.file.exists (tmpDir))
                rmdirRecurse (tmpDir);
            dataArchive = null;
            controlArchive = null;
        } catch (Throwable) {
            // we ignore any error
        }
    }
}
