/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
using GXml.Dom;

class AttrTest {
	private static Document get_doc () {
		Document doc = null;
		try {
			doc = new Document.for_path ("test.xml");
		} catch (DomError e) {
		}
		return doc;
	}

	private static Attr get_attr_new_doc (string name, string value) {
		return get_attr (name, value, get_doc ());
	}

	private static Attr get_attr (string name, string value, Document doc) {
		Attr attr = doc.create_attribute (name);
		attr.value = value;
		return attr;
	}

	private static Element get_elem (string name, Document doc) {
		Element elem = doc.create_element (name);
		return elem;
	}

	public static void add_attribute_tests () {
		Test.add_func ("/gdom/attribute/node_name", () => {
				Document doc = get_doc ();
				Attr attr = get_attr ("broomSeries", "Nimbus", doc);

				assert (attr.node_name == "broomSeries");
			});
		Test.add_func ("/gdom/attribute/node_value", () => {
				Document doc = get_doc ();
				Attr attr = doc.create_attribute ("bank");

				assert (attr.node_value == "");
				attr.node_value = "Gringots";
				assert (attr.node_value == "Gringots");
				attr.node_value = "Wizardlies";
				assert (attr.node_value == "Wizardlies");
				/* make sure changing .value changes .node_value */
				attr.value = "Gringots";
				assert (attr.node_value == "Gringots");
			});
		Test.add_func ("/gdom/attribute/name", () => {
				Document doc = get_doc ();
				Attr attr = get_attr ("broomSeries", "Nimbus", doc);

				assert (attr.name == "broomSeries");
			});
		Test.add_func ("/gdom/attribute/node_value", () => {
				Document doc = get_doc ();
				Attr attr = doc.create_attribute ("bank");

				assert (attr.value == "");
				attr.value = "Gringots";
				assert (attr.value == "Gringots");
				attr.value = "Wizardlies";
				assert (attr.value == "Wizardlies");
				/* make sure changing .node_value changes .value */
				attr.node_value = "Gringots";
				assert (attr.value == "Gringots");
			});
		Test.add_func ("/gdom/attribute/specified", () => {
				// TODO: involves supporting DTDs, which come later
			});
		Test.add_func ("/gdom/attribute/parent_node", () => {
				Document doc = get_doc ();
				Element elem = get_elem ("creature", doc);
				Attr attr = get_attr ("breed", "Dragons", doc);

				assert (attr.parent_node == null);
				elem.set_attribute_node (attr);
				assert (attr.parent_node == null);
			});
		Test.add_func ("/gdom/attribute/previous_sibling", () => {
				Document doc = get_doc ();
				Element elem = get_elem ("creature", doc);
				Attr attr1 = get_attr ("breed", "Dragons", doc);
				Attr attr2 = get_attr ("size", "large", doc);

				elem.set_attribute_node (attr1);
				elem.set_attribute_node (attr2);

				assert (attr1.previous_sibling == null);
				assert (attr2.previous_sibling == null);
			});
		Test.add_func ("/gdom/attribute/next_sibling", () => {
				Document doc = get_doc ();
				Element elem = get_elem ("creature", doc);
				Attr attr1 = get_attr ("breed", "Dragons", doc);
				Attr attr2 = get_attr ("size", "large", doc);

				elem.set_attribute_node (attr1);
				elem.set_attribute_node (attr2);

				assert (attr1.next_sibling == null);
				assert (attr2.next_sibling == null);
			});
		Test.add_func ("/gdom/attribute/insert_before", () => {
				Document doc = get_doc ();
				Attr attr = get_attr ("pie", "Dumbleberry", doc);
				Text txt = doc.create_text_node ("Whipped ");

				assert (attr.value == "Dumbleberry");
				attr.insert_before (txt, attr.child_nodes.first ());
				assert (attr.value == "Whipped Dumbleberry");
				// the Text nodes should be merged
				assert (attr.child_nodes.length == 1);
			});
		Test.add_func ("/gdom/attribute/replace_child", () => {
				Document doc = get_doc ();
				Attr attr = get_attr ("WinningHouse", "Slytherin", doc);
				Text txt = doc.create_text_node ("Gryffindor");

				assert (attr.value == "Slytherin");
				attr.replace_child (txt, attr.child_nodes.item (0));
				assert (attr.value == "Gryffindor");
			});
		Test.add_func ("/gdom/attribute/remove_child", () => {
				Document doc = get_doc ();
				Attr attr = get_attr ("parchment", "MauraudersMap", doc);

				assert (attr.value == "MauraudersMap");
				// mischief managed
				attr.remove_child (attr.child_nodes.last ());
				assert (attr.value == "");
			});
	}
}