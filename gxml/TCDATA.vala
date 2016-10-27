/* TCDATA.vala
 *
 * Copyright (C) 2015  Daniel Espinosa <esodan@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
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

using Gee;

/**
 * Class implemeting {@link GXml.CDATA} interface, not tied to libxml-2.0 library.
 */
public class GXml.TCDATA : GXml.TNode, GXml.CDATA
{
  private string _str = null;
  construct {
    _name = "#cdata";
    _node_type = GXml.NodeType.CDATA_SECTION;
  }
  public TCDATA (GXml.Document d, string text)
    requires (d is GXml.TDocument)
  {
    _doc = d;
    _str = text;
  }
  // GXml.Node
  public override string @value {
    owned get { return _str.dup (); }
    set {}
  }
  // GXml.CDATA
  public string str { owned get { return _str.dup (); } }
}
