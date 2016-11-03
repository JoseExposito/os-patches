/* TNode.vala
 *
 * Copyright (C) 2016  Daniel Espinosa <esodan@gmail.com>
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
using Xml;

/**
 * {@link Parser} implementation using libxml2 engine
 */
public class GXml.XParser : Object, GXml.Parser {
  private DomDocument _document;
  private TextReader tr;
  private Xml.TextWriter tw;

  public bool backup { get; set; }
  public bool indent { get; set; }

  public DomDocument document { get { return _document; } }


  public XParser (DomDocument doc) { _document = doc; }

  construct {
    backup = true;
    indent = false;
  }

  public void write_stream (OutputStream stream,
                            GLib.Cancellable? cancellable) throws GLib.Error {
    var buf = new Xml.Buffer ();
    tw = Xmlx.new_text_writer_memory (buf, 0);
    tw.start_document ();
    tw.set_indent (indent);
    // Root
    if (_document.document_element == null) {
      tw.end_document ();
    }
    var dns = new ArrayList<string> ();
#if DEBUG
    GLib.message ("Starting writting Document child nodes");
#endif
    start_node (_document);
#if DEBUG
    GLib.message ("Ending writting Document child nodes");
#endif
    tw.end_element ();
#if DEBUG
    GLib.message ("Ending Document");
#endif
    tw.end_document ();
    tw.flush ();
    var s = new GLib.StringBuilder ();
    s.append (buf.content ());
    var b = new GLib.MemoryInputStream.from_data (s.data, null);
    stream.splice (b, GLib.OutputStreamSpliceFlags.NONE);
    stream.close ();
  }

  public string write_string () throws GLib.Error  {
    return dump ();
  }
  public void read_string (string str, GLib.Cancellable? cancellable) throws GLib.Error {
    if (str == "")
      throw new ParserError.INVALID_DATA_ERROR (_("Invalid document string, is empty is not allowed"));
    StringBuilder s = new StringBuilder (str);
    var stream = new GLib.MemoryInputStream.from_data (str.data);
    read_stream (stream, cancellable);
  }


  public void read_stream (GLib.InputStream istream,
                          GLib.Cancellable? cancellable) throws GLib.Error {
    var b = new MemoryOutputStream.resizable ();
    b.splice (istream, 0);
#if DEBUG
    GLib.message ("DATA:"+(string)b.data);
#endif
    tr = new TextReader.for_memory ((char[]) b.data, (int) b.get_data_size (), "/gxml_memory");
    while (read_node (_document));
  }


  /**
   * Parse current node in {@link Xml.TextReader}.
   *
   * Returns: a {@link GXml.Node} respresenting current parsed one.
   */
  public bool read_node (DomNode node) throws GLib.Error {
    GXml.DomNode n = null;
    string prefix = null, nsuri = null;
#if DEBUG
    GLib.message ("ReadNode: Current Node:"+node.node_name);
#endif
    int res = tr.read ();
    if (res == -1)
      throw new ParserError.INVALID_DATA_ERROR (_("Can't read node data"));
#if DEBUG
    if (res == 0)
      GLib.message ("ReadNode: No more nodes");
#endif
    if (res == 0) return false;
    var t = tr.node_type ();
    switch (t) {
    case Xml.ReaderType.NONE:
#if DEBUG
      GLib.message ("Type NONE");
#endif
      res = tr.read ();
      if (res == -1)
        throw new ParserError.INVALID_DATA_ERROR (_("Can't read node data"));
      break;
    case Xml.ReaderType.ELEMENT:
      bool isempty = (tr.is_empty_element () == 1);
#if DEBUG
      if (isempty) GLib.message ("Is Empty node:"+node.node_name);
      GLib.message ("ReadNode: Element: "+tr.const_local_name ());
#endif
      prefix = tr.prefix ();
      if (prefix != null) {
        GLib.message ("Is namespaced element");
        nsuri = tr.lookup_namespace (prefix);
        n = _document.create_element_ns (nsuri, tr.prefix () +":"+ tr.const_local_name ());
      } else
        n = _document.create_element (tr.const_local_name ());
      node.append_child (n);
      var nattr = tr.attribute_count ();
#if DEBUG
      GLib.message ("Number of Attributes:"+nattr.to_string ());
#endif
      for (int i = 0; i < nattr; i++) {
        var c = tr.move_to_attribute_no (i);
#if DEBUG
        GLib.message ("Current Attribute: "+i.to_string ());
#endif
        if (c != 1) {
          throw new DomError.HIERARCHY_REQUEST_ERROR (_("Parsing ERROR: Fail to move to attribute number: %i").printf (i));
        }
        if (tr.is_namespace_decl () == 1) {
//#if DEBUG
          GLib.message ("Is Namespace Declaration...");
//#endif
          string nsp = tr.const_local_name ();
          string aprefix = tr.prefix ();
          tr.read_attribute_value ();
          if (tr.node_type () == Xml.ReaderType.TEXT) {
            string ansuri = tr.read_string ();
            GLib.message ("Read: "+aprefix+":"+nsp+"="+ansuri);
            string ansp = nsp;
            if (nsp != "xmlns")
              ansp = aprefix+":"+nsp;
            GLib.message ("To append: "+ansp+"="+ansuri);
            (n as DomElement).set_attribute_ns ("http://www.w3.org/2000/xmlns/",
                                                 ansp, ansuri);
          }
        } else {
          var attrname = tr.const_local_name ();
          prefix = tr.prefix ();
#if DEBUG
          GLib.message ("Attribute: "+tr.const_local_name ());
#endif
          tr.read_attribute_value ();
          if (tr.node_type () == Xml.ReaderType.TEXT) {
            var attrval = tr.read_string ();
#if DEBUG
            GLib.message ("Attribute:"+attrname+" Value: "+attrval);
#endif
            if (prefix != null) {
              GLib.message ("Prefix found: "+prefix);
              if (prefix == "xml")
                nsuri = "http://www.w3.org/2000/xmlns/";
              else
                nsuri = tr.lookup_namespace (prefix);
              (n as DomElement).set_attribute_ns (nsuri, prefix+":"+attrname, attrval);
            } else
              (n as DomElement).set_attribute (attrname, attrval);
          }
        }
      }
      if (isempty) return true;
      while (read_node (n) == true);
#if DEBUG
      //GLib.message ("Current Document: "+node.document.to_string ());
#endif
      break;
    case Xml.ReaderType.ATTRIBUTE:
#if DEBUG
      GLib.message ("Type ATTRIBUTE");
#endif
      break;
    case Xml.ReaderType.TEXT:
      var txtval = tr.read_string ();
#if DEBUG
      GLib.message ("Type TEXT");
      GLib.message ("ReadNode: Text Node : '"+txtval+"'");
#endif
      n = _document.create_text_node (txtval);
      node.append_child (n);
      break;
    case Xml.ReaderType.CDATA:
      break;
    case Xml.ReaderType.ENTITY_REFERENCE:
#if DEBUG
      GLib.message ("Type ENTITY_REFERENCE");
#endif
      break;
    case Xml.ReaderType.ENTITY:
#if DEBUG
      GLib.message ("Type ENTITY");
#endif
      break;
    case Xml.ReaderType.PROCESSING_INSTRUCTION:
      var pit = tr.const_local_name ();
      var pival = tr.value ();
#if DEBUG
      GLib.message ("Type PROCESSING_INSTRUCTION");
      GLib.message ("ReadNode: PI Node : '"+pit+"' : '"+pival+"'");
#endif
      n = node.owner_document.create_processing_instruction (pit,pival);
      node.append_child (n);
      break;
    case Xml.ReaderType.COMMENT:
      var commval = tr.value ();
#if DEBUG
      GLib.message ("Type COMMENT");
      GLib.message ("ReadNode: Comment Node : '"+commval+"'");
#endif
      n = node.owner_document.create_comment (commval);
      node.append_child (n);
      break;
    case Xml.ReaderType.DOCUMENT:
#if DEBUG
      GLib.message ("Type DOCUMENT");
#endif
      break;
    case Xml.ReaderType.DOCUMENT_TYPE:
#if DEBUG
      GLib.message ("Type DOCUMENT_TYPE");
#endif
      break;
    case Xml.ReaderType.DOCUMENT_FRAGMENT:
#if DEBUG
      GLib.message ("Type DOCUMENT_FRAGMENT");
#endif
      break;
    case Xml.ReaderType.NOTATION:
#if DEBUG
      GLib.message ("Type NOTATION");
#endif
      break;
    case Xml.ReaderType.WHITESPACE:
#if DEBUG
      GLib.message ("Type WHITESPACE");
#endif
      break;
    case Xml.ReaderType.SIGNIFICANT_WHITESPACE:
      var stxtval = tr.read_string ();
#if DEBUG
      GLib.message ("ReadNode: Text Node : '"+stxtval+"'");
      GLib.message ("Type SIGNIFICANT_WHITESPACE");
#endif
      n = _document.create_text_node (stxtval);
      node.append_child (n);
      break;
    case Xml.ReaderType.END_ELEMENT:
#if DEBUG
      GLib.message ("Type END_ELEMENT");
#endif
      return false;
    case Xml.ReaderType.END_ENTITY:
#if DEBUG
      GLib.message ("Type END_ENTITY");
#endif
      return false;
    case Xml.ReaderType.XML_DECLARATION:
#if DEBUG
      GLib.message ("Type XML_DECLARATION");
#endif
      break;
    }
    return true;
  }

  private string dump () throws GLib.Error {
    int size;
    Xml.Doc doc = new Xml.Doc ();
    tw = Xmlx.new_text_writer_doc (ref doc);
    tw.start_document ();
    tw.set_indent (indent);
    // Root
    if (_document.document_element == null) {
      tw.end_document ();
    }
    var dns = new ArrayList<string> ();
#if DEBUG
    GLib.message ("Starting writting Document child nodes");
#endif
    start_node (_document);
#if DEBUG
    GLib.message ("Ending writting Document child nodes");
#endif
    tw.end_element ();
#if DEBUG
    GLib.message ("Ending Document");
#endif
    tw.end_document ();
    tw.flush ();
    string str;
    doc.dump_memory (out str, out size);
    if (str != null)
      GLib.message ("STR: "+str);
    return str;
  }
  private void start_node (GXml.DomNode node)
    throws GLib.Error
  {
    GLib.message ("Starting node...");
    int size = 0;
#if DEBUG
    GLib.message (@"Starting Node: start Node: '$(node.node_name)'");
#endif
    if (node is GXml.DomElement) {
#if DEBUG
      GLib.message (@"Starting Element... '$(node.node_name)'");
      GLib.message (@"Element Document is Null... '$((node.owner_document == null).to_string ())'");
#endif
      if ((node as DomElement).prefix != null
          || (node as DomElement).namespace_uri != null) {
        string name = (node as DomElement).prefix
                      + ":" + (node as DomElement).local_name;
        tw.start_element (name);
      }
      if ((node as DomElement).prefix == null
            && (node as DomElement).namespace_uri != null) {
            GLib.message ("Writting namespace definition for node");
          tw.start_element_ns (null,
                               (node as DomElement).local_name,
                               (node as DomElement).namespace_uri);
      } else
        tw.start_element (node.node_name);
    GLib.message ("Write down properties: size:"+(node as DomElement).attributes.size.to_string ());

    foreach (string ak in (node as DomElement).attributes.keys) {
      string v = ((node as DomElement).attributes as HashMap<string,string>).get (ak);
      size += tw.write_attribute (ak, v);
      size += tw.end_attribute ();
      if (size > 1500)
        tw.flush ();
    }
  }
  // Non Elements
#if DEBUG
    GLib.message (@"Starting Element: writting Node '$(node.node_name)' children");
#endif
    foreach (GXml.DomNode n in node.child_nodes) {
#if DEBUG
      GLib.message (@"Child Node is: $(n.get_type ().name ())");
#endif
      if (n is GXml.DomElement) {
#if DEBUG
      GLib.message (@"Starting Child Element: writting Node '$(n.node_name)'");
#endif
        start_node (n);
        size += tw.end_element ();
        if (size > 1500)
          tw.flush ();
      }
      if (n is GXml.DomText) {
      //GLib.message ("Writting Element's contents");
      size += tw.write_string (n.node_value);
      if (size > 1500)
        tw.flush ();
      }
      if (n is GXml.DomComment) {
#if DEBUG
      GLib.message (@"Starting Child Element: writting Comment '$(n.node_value)'");
#endif
        size += tw.write_comment (n.node_value);
        if (size > 1500)
          tw.flush ();
      }
      if (n is GXml.DomProcessingInstruction) {
  #if DEBUG
      GLib.message (@"Starting Child Element: writting ProcessingInstruction '$(n.node_value)'");
  #endif
        size += Xmlx.text_writer_write_pi (tw, (n as DomProcessingInstruction).target,
                                          (n as DomProcessingInstruction).data);
        if (size > 1500)
          tw.flush ();
      }
    }
  }
}
