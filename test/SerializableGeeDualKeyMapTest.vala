/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/**
 *
 *  GXml.Serializable.BasicTypeTest
 *
 *  Authors:
 *
 *       Daniel Espinosa <esodan@gmail.com>
 *
 *
 *  Copyright (c) 2013-2015 Daniel Espinosa
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
using GXml;
using Gee;

class Spaces : SerializableObjectModel, SerializableMapDualKey<string,string>
{
  public string get_map_primary_key  () { return owner; }
  public string get_map_secondary_key () { return name; }
  public string name { get; set; }
  public string owner { get; set; }
  public Spaces.full ( string owner, string name)
  {
    this.name = name;
    this.owner = owner;
  }
  public override string to_string () { return name; }
}

class SerializableGeeDualKeyMapTest : GXmlTest
{

  class DHElement : SerializableObjectModel, SerializableMapDualKey<string,string>
  {
    public string name { get; set; }
    public string key { get; set; }
    public string get_map_primary_key  () { return key; }
    public string get_map_secondary_key () { return name; }
    public override string node_name () { return "DHElement"; }
    public override string to_string () { return "DHElement"; }
    public class DualKeyMap : SerializableDualKeyMap<string,string,DHElement> {
      public bool enable_deserialize { get; set; default = false; }
      public override bool deserialize_proceed () { return enable_deserialize; }
    }
  }
  class DHCElement : SerializableObjectModel {
    public DHElement.DualKeyMap elements1 { get; set; default = new DHElement.DualKeyMap (); }
    public DHElement.DualKeyMap elements2 { get; set; default = new DHElement.DualKeyMap (); }
    public override string node_name () { return "DHCElement"; }
    public override string to_string () { return "DHCElement"; }
  }
  public static void add_tests ()
  {
    Test.add_func ("/gxml/serializable/serializable_dual_key_map/api",
    () => {
        var c = new SerializableDualKeyMap<string,string,Spaces> ();
        var o1 = new Spaces.full ("Floor", "Big");
        var o2 = new Spaces.full ("Wall", "Small");
        var o3 = new Spaces.full ("Floor", "Bigger");
        var o4 = new Spaces.full ("Wall","Smallest");
        c.set (o1.owner, o1.name, o1);
        c.set (o2.owner, o2.name, o2);
        c.set (o3.owner, o3.name, o3);
        c.set (o4.owner, o4.name, o4);
        if (c.size != 4) {
          stdout.printf (@"SIZE: $(c.size)\n");
          assert_not_reached ();
        }
        bool found1 = false;
        bool found2 = false;
        bool found3 = false;
        bool found4 = false;
        foreach (Spaces s in c.values ()) {
          if (s.owner == "Floor" && s.name == "Big")
            found1 = true;
          if (s.owner == "Wall" && s.name == "Small")
            found2 = true;
          if (s.owner == "Floor" && s.name == "Bigger")
            found3 = true;
          if (s.owner == "Wall" && s.name == "Smallest")
            found4 = true;
        }
        if (!found1) {
          stdout.printf (@"Not found 'Floor' & 'Big':\n");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"Not found 'Wall' & 'Small':\n");
          assert_not_reached ();
        }
        if (!found3) {
          stdout.printf (@"Not found 'Floor' & 'Bigger':\n");
          assert_not_reached ();
        }
        if (!found4) {
          stdout.printf (@"Not found 'Wall' & 'Smallest':\n");
          assert_not_reached ();
        }
        found1 = found3 = false;
        foreach (Spaces s in c.values_for_key ("Floor")) {
          if (s.owner == "Floor" && s.name == "Big")
            found1 = true;
          if (s.owner == "Floor" && s.name == "Bigger")
            found3 = true;
        }
        if (!found1) {
          stdout.printf (@"Not found 'Floor' & 'Big':\n");
          assert_not_reached ();
        }
        if (!found3) {
          stdout.printf (@"Not found 'Floor' & 'Bigger':\n");
          assert_not_reached ();
        }
        found2 = found4 = true;
        foreach (string k2 in c.secondary_keys ("Wall")) {
          var s = c.get ("Wall", k2);
          if (s.owner == "Wall" && s.name == "Small")
            found2 = true;
          if (s.owner == "Wall" && s.name == "Smallest")
            found4 = true;
        }
        if (!found2) {
          stdout.printf (@"Not found 'Wall' & 'Small':\n");
          assert_not_reached ();
        }
        if (!found4) {
          stdout.printf (@"Not found 'Wall' & 'Smallest':\n");
          assert_not_reached ();
        }
    });
    Test.add_func ("/gxml/serializable/serializable_dual_key_map/serialize",
    () => {
      try {
        var c = new SerializableDualKeyMap<string,string,Spaces> ();
        var o1 = new Spaces.full ("Floor", "Big");
        var o2 = new Spaces.full ("Wall", "Small");
        var o3 = new Spaces.full ("Floor", "Bigger");
        var o4 = new Spaces.full ("Wall","Smallest");
        c.set (o1.owner, o1.name, o1);
        c.set (o2.owner, o2.name, o2);
        c.set (o3.owner, o3.name, o3);
        c.set (o4.owner, o4.name, o4);
        var doc = new TwDocument ();
        var root = doc.create_element ("root");
        doc.children.add (root);
        c.serialize (root);
        assert (root.children.size == 4);
        bool found1 = false;
        bool found2 = false;
        bool found3 = false;
        bool found4 = false;
        int nodes = 0;
        int i = 0;
        foreach (GXml.Node n in root.children) {
          nodes++;
          if (n is Element && n.name == "spaces") {
            i++;
            var name = n.attrs.get ("name");
            var owner = n.attrs.get ("owner");
            if (name != null && owner != null) {
              if (name.value == "Big" && owner.value == "Floor") found1 = true;
              if (name.value == "Small" && owner.value == "Wall") found2 = true;
              if (name.value == "Bigger" && owner.value == "Floor") found3 = true;
              if (name.value == "Smallest" && owner.value == "Wall") found4 = true;
            }
          }
        }
        if (i != 4) {
          stdout.printf (@"ERROR: Incorrect number of space nodes. Expected 4, got: $nodes\n$(doc)");
          assert_not_reached ();
        }
        // Consider that root node contents have a valid GXml.Text one
        if (nodes != 4) {
          stdout.printf (@"ERROR: Incorrect number of nodes. Expected 5, got: $nodes\n$(doc)");
          assert_not_reached ();
        }
        if (!found1) {
          stdout.printf (@"ERROR: 'Big' / 'Floor' not found\n$(doc)");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"ERROR: 'Small' / 'Wall' not found\n$(doc)");
          assert_not_reached ();
        }
        if (!found3) {
          stdout.printf (@"ERROR: 'Bigger' / 'Floor' not found\n$(doc)");
          assert_not_reached ();
        }
        if (!found4) {
          stdout.printf (@"ERROR: 'Smallest' / 'Wall' not found\n$(doc)");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/serializable/serializable_dual_key_map/deserialize",
    () => {
      try {
        var doc = new GDocument.from_string ("""<?xml version="1.0"?>
<root><spaces name="Small" owner="Wall"/><spaces name="Smallest" owner="Wall"/><spaces name="Big" owner="Floor"/><spaces name="Bigger" owner="Floor"/><spark /></root>""");
        var c = new SerializableDualKeyMap<string,string,Spaces> ();
        c.deserialize (doc.root);
        if (c.size != 4) {
          stdout.printf (@"ERROR: incorrect size must be 4 got: $(c.size)\n");
          assert_not_reached ();
        }
        bool found1 = false;
        bool found2 = false;
        bool found3 = false;
        bool found4 = false;
        foreach (Spaces s in c.values ()) {
          if (s.owner == "Floor" && s.name == "Big") found1 = true;
          if (s.owner == "Wall" && s.name == "Small") found2 = true;
          if (s.owner == "Floor" && s.name == "Bigger") found3 = true;
          if (s.owner == "Wall" && s.name == "Smallest") found4 = true;
        }
        if (!found1) {
          stdout.printf (@"ERROR: 'Big' / 'Floor' not found\n$(doc)");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"ERROR: 'Small' / 'Wall' not found\n$(doc)");
          assert_not_reached ();
        }
        if (!found3) {
          stdout.printf (@"ERROR: 'Bigger' / 'Floor' not found\n$(doc)");
          assert_not_reached ();
        }
        if (!found4) {
          stdout.printf (@"ERROR: 'Smallest' / 'Wall' not found\n$(doc)");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/serializable/serializable_dual_key_map/de-se-deserialize",
    () => {
      try {
        var idoc = new GDocument.from_string ("""<?xml version="1.0"?>
<root><spaces name="Small" owner="Wall"/><spaces name="Smallest" owner="Wall"/><spaces name="Big" owner="Floor"/><spaces name="Bigger" owner="Floor"/><spark /></root>""");
        var ic = new SerializableDualKeyMap<string,string,Spaces> ();
        ic.deserialize (idoc.root);
        if (ic.size != 4) {
          stdout.printf (@"ERROR: Incorrect size (1st deserialize). Expected 4, got: $(ic.size)\n$idoc\n");
          assert_not_reached ();
        }
        var doc = new GDocument.from_string ("""<?xml version="1.0"?>
<root />""");
        ic.serialize (doc.root);
        var c =  new SerializableDualKeyMap<string,string,Spaces> ();
        c.deserialize (doc.root);
        if (c.size != 4) {
          stdout.printf (@"ERROR: Incorrect size. Expected 4, got: $(c.size)\n$doc\n");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/serializable/serializable_dual_key_map/deserialize-node-names",
    () => {
      try {
        var d = new GDocument.from_path (GXmlTestConfig.TEST_DIR + "/test-collection.xml");
        var bs = new BookStore ();
        bs.deserialize (d);
        assert (bs.name == "The Great Book");
        assert (bs.books.size == 3);
        var b = bs.books.first ();
        assert (b != null);
        assert (b.name != null);
        assert (b.name.get_name () == "Book1");
        assert (b.year == "2015");
        assert (b.authors != null);
        assert (b.authors.array != null);
        assert (b.authors.array.size == 2);
        assert (b.inventory_registers != null);
        assert (b.inventory_registers.size == 4);
        var ir = b.inventory_registers.get (1,"K001");
        assert (ir != null);
        assert (ir.number == 1);
        assert (ir.inventory == "K001");
        assert (ir.row == 5);
      } catch (GLib.Error e) {
#if DEBUG
        GLib.message ("ERROR: "+e.message);
#endif
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/performance/dualkeymap/post-deserialization/disable",
    () => {
      try {
        double time;
        Test.message ("Starting generating document...");
        Test.timer_start ();
        var d = new TwDocument ();
        var ce = new DHCElement ();
        for (int i = 0; i < 125000; i++) {
          var e1 = new DHElement ();
          e1.key = "E1";
          e1.name = "1E"+i.to_string ();
          ce.elements1.set (e1.key, e1.name, e1);
          var e2 = new DHElement ();
          e2.key = "E2";
          e2.name = "2E"+i.to_string ();
          ce.elements2.set (e2.key, e2.name, e2);
        }
        ce.serialize (d);
        time = Test.timer_elapsed ();
        Test.minimized_result (time, "Created document: %g seconds", time);
        Test.message ("Starting deserializing document: Disable collection deserialization...");
        Test.timer_start ();
        var cep = new DHCElement ();
        cep.elements1.enable_deserialize = false;
        cep.elements2.enable_deserialize = false;
        cep.deserialize (d);
        time = Test.timer_elapsed ();
        Test.minimized_result (time, "Disable Deserialize Collection. Deserialized from doc: %g seconds", time);
        assert (cep.elements1.is_prepared ());
        assert (cep.elements2.is_prepared ());
        Test.message ("Calling C1 deserialize_children()...");
        Test.timer_start ();
        cep.elements1.deserialize_children ();
        assert (!cep.elements1.deserialize_children ());
        time = Test.timer_elapsed ();
        Test.minimized_result (time, "C1: Disable Deserialize Collection. Deserialized from NODE: %g seconds", time);
        Test.message ("Calling C2 deserialize_children()...");
        Test.timer_start ();
        cep.elements2.deserialize_children ();
        assert (!cep.elements2.deserialize_children ());
        time = Test.timer_elapsed ();
        Test.minimized_result (time, "C2: Disable Deserialize Collection. Deserialized from NODE: %g seconds", time);
      } catch (GLib.Error e) {
        GLib.message ("ERROR: "+e.message);
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/performance/dualkeymap/post-deserialization/enable",
    () => {
      try {
        double time;
        Test.message ("Starting generating document...");
        Test.timer_start ();
        var d = new TwDocument ();
        var ce = new DHCElement ();
        for (int i = 0; i < 125000; i++) {
          var e1 = new DHElement ();
          e1.name = "1E"+i.to_string ();
          ce.elements1.set (e1.key, e1.name, e1);
          var e2 = new DHElement ();
          e2.name = "2E"+i.to_string ();
          ce.elements2.set (e2.key, e2.name, e2);
        }
        ce.serialize (d);
        time = Test.timer_elapsed ();
        Test.minimized_result (time, "Created document: %g seconds", time);
        Test.message ("Starting deserializing document: Enable collection deserialization...");
        Test.timer_start ();
        var cep = new DHCElement ();
        cep.elements1.enable_deserialize = true;
        cep.elements2.enable_deserialize = true;
        cep.deserialize (d);
        time = Test.timer_elapsed ();
        Test.minimized_result (time, "Disable Deserialize Collection. Deserialized from doc: %g seconds", time);
        assert (cep.elements1.is_prepared ());
        assert (cep.elements2.is_prepared ());
        assert (!cep.elements1.deserialize_children ());
        assert (!cep.elements2.deserialize_children ());
      } catch (GLib.Error e) {
        GLib.message ("ERROR: "+e.message);
        assert_not_reached ();
      }
    });
  }
}
