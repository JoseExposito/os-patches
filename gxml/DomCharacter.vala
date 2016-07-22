/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 *
 * Copyright (C) 2016  Daniel Espinosa <esodan@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *      Daniel Espinosa <esodan@gmail.com>
 */

public interface GXml.DomCharacterData : GLib.Object,
                  GXml.DomNode,
                  GXml.DomNonDocumentTypeChildNode,
                  GXml.DomChildNode
{
	/**
	 * Null is an empty string.
	 */
  public abstract string data { owned get; set; }

  public virtual ulong length {
    get {
      if (this.data == null) return 0;
      return this.data.length;
    }
  }
  public virtual string substring_data (ulong offset, ulong count) throws GLib.Error {
    if (((int)offset) > this.data.length)
      throw new DomError.INDEX_SIZE_ERROR (_("Invalid offset for substring"));
    int end = (int) (offset + count);
    if (!(end < data.length)) end = data.length;
    return data.slice ((int) offset, end);
  }
  public virtual void append_data  (string data) {
    this.data += data;
  }
  public virtual void insert_data  (ulong offset, string data) throws GLib.Error {
    replace_data (offset, 0, data);
  }
  public virtual void delete_data  (ulong offset, ulong count) throws GLib.Error {
    replace_data (offset, count, "");
  }
  public new virtual void replace_data (ulong offset, ulong count, string data) throws GLib.Error {
    if (((int)offset) > this.data.length)
      throw new DomError.INDEX_SIZE_ERROR (_("Invalid offset for replace data"));
    int end = (int) (offset + count);
    if (!(end < this.data.length)) end = this.data.length;
    this.data = this.data.splice ((int) offset, end, data);
  }
}

public interface GXml.DomText : GXml.DomCharacterData {
  public abstract GXml.DomText split_text(ulong offset) throws GLib.Error;
  public abstract string whole_text { owned get; }
}

public interface GXml.DomProcessingInstruction : GXml.DomCharacterData {
  public abstract string target { owned get; }
}

public interface GXml.DomComment : GXml.DomCharacterData {}

