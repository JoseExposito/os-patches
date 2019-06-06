/* -*- Mode: C; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/*
 *  Copyright © 2013 Igalia S.L.
 *
 *  This file is part of Epiphany.
 *
 *  Epiphany is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Epiphany is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Epiphany.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "config.h"
#include "ephy-web-dom-utils.h"

#include <libsoup/soup.h>
#include <stdio.h>
#include <string.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

typedef struct {
  WebKitDOMHTMLInputElement *element;
  gint index;
} InputElementData;

static InputElementData *
input_element_data_new (WebKitDOMHTMLInputElement *element,
                        gint                       index)
{
  InputElementData *data;

  data = g_slice_new (InputElementData);
  data->element = g_object_ref (element);
  data->index = index;

  return data;
}

static void
input_element_data_free (InputElementData *data)
{
  g_assert (data);

  g_object_unref (data->element);
  g_slice_free (InputElementData, data);
}

/**
 * ephy_web_dom_utils_has_modified_forms:
 * @document: the DOM document to check if there are or not modified forms.
 *
 * A small heuristic is used here. If there's only one input element modified
 * and it does not have a lot of text the user is likely not very interested in
 * saving this work, so it returns %FALSE in this case (eg, google search
 * input).
 *
 * Returns %TRUE if the user has modified &lt;input&gt; or &lt;textarea&gt;
 * values in the @document.
 **/
gboolean
ephy_web_dom_utils_has_modified_forms (WebKitDOMDocument *document)
{
  WebKitDOMHTMLCollection *forms;
  gulong forms_n;
  guint i;
  gboolean modified_forms = FALSE;

  forms = webkit_dom_document_get_forms (document);
  forms_n = webkit_dom_html_collection_get_length (forms);

  for (i = 0; i < forms_n; i++) {
    WebKitDOMHTMLCollection *elements;
    WebKitDOMNode *form_element = webkit_dom_html_collection_item (forms, i);
    gulong elements_n;
    guint j;
    gboolean modified_input_element = FALSE;

    elements = webkit_dom_html_form_element_get_elements (WEBKIT_DOM_HTML_FORM_ELEMENT (form_element));
    elements_n = webkit_dom_html_collection_get_length (elements);

    for (j = 0; j < elements_n; j++) {
      WebKitDOMNode *element;

      element = webkit_dom_html_collection_item (elements, j);

      if (WEBKIT_DOM_IS_HTML_TEXT_AREA_ELEMENT (element))
        if (webkit_dom_html_text_area_element_is_edited (WEBKIT_DOM_HTML_TEXT_AREA_ELEMENT (element))) {
          char *text;
          gboolean has_data;

          text = webkit_dom_html_text_area_element_get_value (WEBKIT_DOM_HTML_TEXT_AREA_ELEMENT (element));
          has_data = text && *text;
          g_free (text);

          if (has_data) {
            g_object_unref (elements);
            modified_forms = TRUE;
            goto out;
          }
        }

      if (WEBKIT_DOM_IS_HTML_INPUT_ELEMENT (element))
        if (webkit_dom_html_input_element_is_edited (WEBKIT_DOM_HTML_INPUT_ELEMENT (element))) {
          glong length;
          char *text;

          /* A small heuristic here. If there's only one input element
           * modified and it does not have a lot of text the user is
           * likely not very interested in saving this work, so do
           * nothing (eg, google search input). */
          if (modified_input_element) {
            g_object_unref (elements);
            modified_forms = TRUE;
            goto out;
          }

          modified_input_element = TRUE;

          text = webkit_dom_html_input_element_get_value (WEBKIT_DOM_HTML_INPUT_ELEMENT (element));
          length = g_utf8_strlen (text, -1);
          g_free (text);

          if (length > 50) {
            g_object_unref (elements);
            modified_forms = TRUE;
            goto out;
          }
        }
    }
    g_object_unref (elements);
  }

 out:
  g_object_unref (forms);
  return modified_forms;
}

/**
 * ephy_web_dom_utils_get_application_title:
 * @document: the DOM document.
 *
 * Returns web application title if it is defined in &lt;meta&gt; elements of
 * @document.
 **/
char *
ephy_web_dom_utils_get_application_title (WebKitDOMDocument *document)
{
  WebKitDOMHTMLCollection *metas;
  char *title = NULL;
  gulong length, i;

  metas = webkit_dom_document_get_elements_by_tag_name_as_html_collection (document, "meta");
  length = webkit_dom_html_collection_get_length (metas);

  for (i = 0; i < length && title == NULL; i++) {
    char *name;
    char *property;
    WebKitDOMNode *node = webkit_dom_html_collection_item (metas, i);

    /* og:site_name is read from the property attribute (standard), but is
     * commonly seen on the web in the name attribute. Both are supported. */
    name = webkit_dom_html_meta_element_get_name (WEBKIT_DOM_HTML_META_ELEMENT (node));
    property = webkit_dom_element_get_attribute (WEBKIT_DOM_ELEMENT (node), "property");
    if (name != NULL && g_ascii_strcasecmp (name, "application-name") == 0) {
      g_free (title);
      title = webkit_dom_html_meta_element_get_content (WEBKIT_DOM_HTML_META_ELEMENT (node));
      break;  /* Best name candidate. */
    } else if ((property != NULL && g_ascii_strcasecmp (property, "og:site_name") == 0) ||
               (name != NULL && g_ascii_strcasecmp (name, "og:site_name") == 0)) {
      g_free (title);
      title = webkit_dom_html_meta_element_get_content (WEBKIT_DOM_HTML_META_ELEMENT (node));
    }
    g_free (property);
    g_free (name);
  }
  g_object_unref (metas);

  return title;
}

static char *
resolve_uri (const char *base_uri,
             const char *uri)
{
  SoupURI *base;
  SoupURI *new;
  char *ret;

  if (uri == NULL)
    return NULL;

  if (base_uri == NULL)
    return NULL;

  base = soup_uri_new (base_uri);
  new = soup_uri_new_with_base (base, uri);
  soup_uri_free (base);
  ret = soup_uri_to_string (new, FALSE);
  soup_uri_free (new);

  return ret;
}

static gboolean
get_icon_from_html_icon (WebKitDOMDocument *document,
                         char             **uri_out)
{
  gboolean ret;
  WebKitDOMHTMLCollection *links;
  gulong length, i;
  char *image = NULL;
  int largest_icon = 0;

  links = webkit_dom_document_get_elements_by_tag_name_as_html_collection (document, "link");
  length = webkit_dom_html_collection_get_length (links);

  for (i = 0; i < length; i++) {
    char *rel;
    WebKitDOMNode *node = webkit_dom_html_collection_item (links, i);

    rel = webkit_dom_html_link_element_get_rel (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
    if (rel != NULL && (
        g_ascii_strcasecmp (rel, "icon") == 0 ||
        g_ascii_strcasecmp (rel, "shortcut icon") == 0 ||
        g_ascii_strcasecmp (rel, "icon shortcut") == 0 ||
        g_ascii_strcasecmp (rel, "shortcut-icon") == 0)) {
      char *sizes;
      int width;
      int height;

      g_free (rel);

      sizes = webkit_dom_element_get_attribute (WEBKIT_DOM_ELEMENT (node), "sizes");
      if (sizes != NULL) {
        if (g_ascii_strcasecmp (sizes, "any") == 0) {
          g_free (sizes);
          g_free (image);

          /* TODO: Keep the SVG rather than rasterizing it to PNG. */
          image = webkit_dom_html_link_element_get_href (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
          /* "any" means a vector, and thus it will always be the largest icon. */
          break;
        }

        /* Only accept square icons. */
        if (sscanf (sizes, "%ix%i", &width, &height) != 2 || width != height) {
          g_free (sizes);
          continue;
        }

        /* Only accept icons of 96 px (smallest GNOME HIG app icon) or larger.
         * It's better to defer to other icon discovery methods if smaller
         * icons are returned here. */
        if (width >= 96 && width > largest_icon) {
          g_free (image);
          image = webkit_dom_html_link_element_get_href (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
          largest_icon = width;  /* Keep largest candidate if multiple are found. */
        }
        g_free (sizes);
      }
    }
    else
      g_free (rel);
  }
  g_object_unref (links);

  ret = (image != NULL && *image != '\0');

  if (uri_out != NULL)
    *uri_out = image;

  return ret;
}

static gboolean
get_icon_from_mstile (WebKitDOMDocument *document,
                      char             **uri_out,
                      char             **color_out)
{
  gboolean ret;
  WebKitDOMHTMLCollection *metas;
  gulong length, i;
  char *image = NULL;
  char *color = NULL;

  metas = webkit_dom_document_get_elements_by_tag_name_as_html_collection (document, "meta");
  length = webkit_dom_html_collection_get_length (metas);

  /* FIXME: Ought to also search browserconfig.xml
   * See: http://stackoverflow.com/questions/24625305/msapplication-tileimage-favicon-backup
   */
  for (i = 0; i < length; i++) {
    WebKitDOMNode *node = webkit_dom_html_collection_item (metas, i);
    char *name;

    name = webkit_dom_html_meta_element_get_name (WEBKIT_DOM_HTML_META_ELEMENT (node));
    if (name != NULL) {
      if (g_ascii_strcasecmp (name, "msapplication-TileImage") == 0) {
        g_free (image);
        image = webkit_dom_html_meta_element_get_content (WEBKIT_DOM_HTML_META_ELEMENT (node));
      }
      else if (g_ascii_strcasecmp (name, "msapplication-TileColor") == 0) {
        g_free (color);
        color = webkit_dom_html_meta_element_get_content (WEBKIT_DOM_HTML_META_ELEMENT (node));
      }
    }
  }
  g_object_unref (metas);

  ret = (image != NULL && *image != '\0');

  if (uri_out != NULL)
    *uri_out = image;
  if (color_out != NULL)
    *color_out = color;

  return ret;
}

static gboolean
get_icon_from_ogp (WebKitDOMDocument *document,
                   char             **uri_out)
{
  gboolean ret;
  WebKitDOMHTMLCollection *metas;
  gulong length, i;
  char *image = NULL;

  metas = webkit_dom_document_get_elements_by_tag_name_as_html_collection (document, "meta");
  length = webkit_dom_html_collection_get_length (metas);

  for (i = 0; i < length && image == NULL; i++) {
    WebKitDOMNode *node = webkit_dom_html_collection_item (metas, i);
    char *property;
    char *itemprop;

    property = webkit_dom_element_get_attribute (WEBKIT_DOM_ELEMENT (node), "property");
    itemprop = webkit_dom_element_get_attribute (WEBKIT_DOM_ELEMENT (node), "itemprop");
    if ((property != NULL && g_ascii_strcasecmp (property, "og:image") == 0) ||
        (itemprop != NULL && g_ascii_strcasecmp (itemprop, "image") == 0)) {
      g_free (image);
      image = webkit_dom_html_meta_element_get_content (WEBKIT_DOM_HTML_META_ELEMENT (node));
    }
    g_free (property);
    g_free (itemprop);
  }
  g_object_unref (metas);

  ret = (image != NULL && *image != '\0');

  if (uri_out != NULL)
    *uri_out = image;

  return ret;
}

static gboolean
get_icon_from_touch_icon (WebKitDOMDocument *document,
                          char             **uri_out)
{
  gboolean ret;
  WebKitDOMHTMLCollection *links;
  gulong length, i;
  char *image = NULL;

  links = webkit_dom_document_get_elements_by_tag_name_as_html_collection (document, "link");
  length = webkit_dom_html_collection_get_length (links);

  for (i = 0; i < length && image == NULL; i++) {
    char *rel;
    WebKitDOMNode *node = webkit_dom_html_collection_item (links, i);

    rel = webkit_dom_html_link_element_get_rel (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
    /* TODO: support more than one possible icon. */
    if (rel != NULL) {
      if (g_ascii_strcasecmp (rel, "apple-touch-icon") == 0) {
        g_free (image);
        image = webkit_dom_html_link_element_get_href (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
        break;  /* Best touch-icon candidate. */
      } else if (g_ascii_strcasecmp (rel, "apple-touch-icon-precomposed") == 0) {
        g_free (image);
        image = webkit_dom_html_link_element_get_href (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
      }
    }
    g_free (rel);
  }
  g_object_unref (links);

  /* TODO: Try to retrieve /apple-touch-icon.png, and return it if it exist. */

  ret = (image != NULL && *image != '\0');

  if (uri_out != NULL)
    *uri_out = image;

  return ret;
}

static void
get_icon_from_favicon (WebKitDOMDocument *document,
                       char             **uri_out)
{
  WebKitDOMHTMLCollection *links;
  gulong length, i;
  char *image = NULL;

  links = webkit_dom_document_get_elements_by_tag_name_as_html_collection (document, "link");
  length = webkit_dom_html_collection_get_length (links);

  for (i = 0; i < length; i++) {
    char *rel;
    WebKitDOMNode *node = webkit_dom_html_collection_item (links, i);

    rel = webkit_dom_html_link_element_get_rel (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
    if (rel != NULL && (
        g_ascii_strcasecmp (rel, "icon") == 0 ||
        g_ascii_strcasecmp (rel, "shortcut icon") == 0 ||
        g_ascii_strcasecmp (rel, "icon shortcut") == 0 ||
        g_ascii_strcasecmp (rel, "shortcut-icon") == 0)) {
      g_free (image);
      image = webkit_dom_html_link_element_get_href (WEBKIT_DOM_HTML_LINK_ELEMENT (node));
    }
    g_free (rel);
  }
  g_object_unref (links);

  /* Last ditch effort: just fallback to the default favicon location. */
  if (image == NULL)
    image = g_strdup ("/favicon.ico");

  if (uri_out != NULL)
    *uri_out = image;
}

/**
 * ephy_web_dom_utils_get_best_icon:
 * @document: the DOM document.
 * @base_uri: base URI of the #WebKitWebView.
 * @uri_out: Icon URI.
 * @color_out: Icon background color.
 *
 * Tries to get the icon (and its background color if any) for a web application
 * from the @document meta data. First try to get a large standard icon, then mstile,
 * then OpenGraph, then touch icon, and finally use the favicon.
 *
 * Returns %TRUE if it finds an icon in the @document.
 **/
void
ephy_web_dom_utils_get_best_icon (WebKitDOMDocument *document,
                                  const char        *base_uri,
                                  char             **uri_out,
                                  char             **color_out)
{
  gboolean found_icon = FALSE;
  char *image = NULL;
  char *color = NULL;

  /* FIXME: These functions could be improved considerably. See the first two answers at:
   * http://stackoverflow.com/questions/21991044/how-to-get-high-resolution-website-logo-favicon-for-a-given-url
   *
   * Also check out: https://www.slightfuture.com/webdev/gnome-web-app-icons
   */
  found_icon = get_icon_from_html_icon (document, &image);
  if (!found_icon)
    found_icon = get_icon_from_mstile (document, &image, &color);
  if (!found_icon)
    found_icon = get_icon_from_touch_icon (document, &image);
  if (!found_icon)
    found_icon = get_icon_from_ogp (document, &image);
  if (!found_icon)
    get_icon_from_favicon (document, &image);

  if (uri_out != NULL)
    *uri_out = resolve_uri (base_uri, image);
  if (color_out != NULL)
    *color_out = color;

  g_free (image);
}

GPtrArray *
ephy_web_dom_utils_find_password_fields (WebKitDOMHTMLFormElement *form,
                                         AuthCacheMode             mode)
{
  GPtrArray *password_fields = NULL;
  WebKitDOMHTMLCollection *elements;
  guint i, n_elements;

  password_fields = g_ptr_array_new_full (3, (GDestroyNotify)input_element_data_free);

  elements = webkit_dom_html_form_element_get_elements (form);
  n_elements = webkit_dom_html_collection_get_length (elements);

  for (i = 0; i < n_elements; i++) {
    WebKitDOMNode *element;
    char *element_type;
    char *element_value;
    InputElementData *data;

    element = webkit_dom_html_collection_item (elements, i);
    if (!WEBKIT_DOM_IS_HTML_INPUT_ELEMENT (element))
      continue;

    g_object_get (element, "type", &element_type, "value", &element_value, NULL);
    if (g_strcmp0 (element_type, "password") != 0)
      goto next;

    if ((element_value == NULL || strlen (element_value) == 0) &&
        mode == AUTH_CACHE_SUBMIT)
      goto next;

    data = input_element_data_new (WEBKIT_DOM_HTML_INPUT_ELEMENT (element), i);

    g_ptr_array_add (password_fields, data);

next:
    g_free (element_type);
    g_free (element_value);
  }

  g_object_unref (elements);

  /*
   * We only want to process forms with 1-3 fields. A common
   * case is to have a "change password" form with 3 fields:
   * Old password, New password, Confirm new password.
   * Forms with more than 3 password fields are unlikely,
   * and we don't know how to process them, so reject them
   */
  if (password_fields->len == 0 || password_fields->len > 3) {
    g_ptr_array_free (password_fields, TRUE);
    return NULL;
  }

  return password_fields;
}

/*
 * The heuristic is based on the one used in Firefox. See
 * https://dxr.mozilla.org/mozilla-central/rev/892c8916ba32b7733e06bfbfdd4083ffae3ca028/toolkit/components/passwordmgr/LoginManagerContent.jsm#733
 */
gboolean
ephy_web_dom_utils_find_form_auth_elements (WebKitDOMHTMLFormElement *form,
                                            WebKitDOMNode           **username,
                                            WebKitDOMNode           **password,
                                            AuthCacheMode             mode)
{
  WebKitDOMHTMLCollection *elements;
  WebKitDOMHTMLInputElement *username_node = NULL;
  WebKitDOMHTMLInputElement *password_node = NULL;
  gint i, password_node_index = 0;
  GPtrArray *password_nodes = NULL;
  gchar **passwords;
  InputElementData *first_password_node_data = NULL;

  password_nodes = ephy_web_dom_utils_find_password_fields (form, mode);
  if (password_nodes == NULL)
    return FALSE;

  /*
   * Start at the first found password field and search backwards.
   * Assume the first eligible field to contain username
   */
  first_password_node_data = g_ptr_array_index (password_nodes, 0);
  elements = webkit_dom_html_form_element_get_elements (form);
  for (i = first_password_node_data->index; i >= 0; i--) {
    WebKitDOMNode *element;
    gchar *element_type;

    element = webkit_dom_html_collection_item (elements, i);
    if (!WEBKIT_DOM_IS_HTML_INPUT_ELEMENT (element))
      continue;

    g_object_get (element, "type", &element_type, NULL);
    if (g_strcmp0 (element_type, "text") == 0 ||
        g_strcmp0 (element_type, "email") == 0 ||
        g_strcmp0 (element_type, "tel") == 0 ||
        g_strcmp0 (element_type, "url") == 0 ||
        g_strcmp0 (element_type, "number") == 0) {
      username_node = g_object_ref (WEBKIT_DOM_HTML_INPUT_ELEMENT (element));
      g_free (element_type);
      break;
    }

    g_free (element_type);
  }

  /*
   * Choose password field that contains the password that we want to store
   * To do that, we compare the field values. We can only do this when user
   * submits login data, because otherwise all the fields are empty. In that
   * case just pick the first field
   */
  if (mode == AUTH_CACHE_AUTOFILL || password_nodes->len == 1) {
    /* If mode == AUTH_CACHE_AUTOFILL, we expect all fields to be empty */
    password_node_index = 0;
  } else {
    /* Get values of all password fields */
    passwords = g_malloc0 (password_nodes->len * sizeof (gchar *));
    for (i = password_nodes->len - 1; i >= 0; i--) {
      WebKitDOMHTMLInputElement *element;
      element = ((InputElementData *) g_ptr_array_index (password_nodes, i))->element;
      passwords[i] = webkit_dom_html_input_element_get_value (element);
    }

    if (password_nodes->len == 2) {
      /*
       * If there are two password fields, assume that the form has either
       * Password and Confirm password fields, or Old password and New password.
       * That can be guessed by comparing values in the fields. If they are
       * different, we assume that the second password is "new" and use it.
       * If they match, then just take the first field.
       */
      if (g_strcmp0 (passwords[0], passwords[1]) == 0) {
        /* Password / Confirm password */
        password_node_index = 0;
      } else {
        /* Old password / New password */
        password_node_index = 1;
      }
    } else if (password_nodes->len == 3) {
      /*
       * This is probably a complete Old password, New password, Confirm
       * new password case. Here we assume that if two fields have the same
       * value, then it's the new password and we should take it. A special
       * case is when all 3 passwords are different. We don't know what to
       * do in this case, so just reject the form,
       */
      if (g_strcmp0 (passwords[0], passwords[1]) == 0 &&
          g_strcmp0 (passwords[1], passwords[2]) == 0) {
        /* All values are same */
        password_node_index = 0;
      } else if (g_strcmp0 (passwords[0], passwords[1]) == 0) {
        /* New password / Confirm new password / Old password */
        password_node_index = 0;
      } else if (g_strcmp0 (passwords[0], passwords[2]) == 0) {
        /* New password / Old password / Confirm new password */
        password_node_index = 0;
      } else if (g_strcmp0 (passwords[1], passwords[2]) == 0) {
        /* Old password / New password / Confirm new password */
        password_node_index = 1;
      } else {
        /* All values are different. Reject the form */
        password_node_index = -1;
      }
    }

    for (i = 0; i < password_nodes->len; i++)
      g_free (passwords[i]);
    g_free (passwords);
  }

  if (password_node_index >= 0) {
    InputElementData *password_data = g_ptr_array_index (password_nodes,
                                                         password_node_index);
    password_node = g_object_ref (password_data->element);
  }

  if (username_node)
    *username = WEBKIT_DOM_NODE (username_node);
  if (password_node)
    *password = WEBKIT_DOM_NODE (password_node);

  g_object_unref (elements);
  g_ptr_array_free (password_nodes, TRUE);

  if (*password)
    return TRUE;

  if (username_node)
    g_object_unref (username_node);
  if (password_node)
    g_object_unref (password_node);

  return FALSE;
}

/* ephy_web_dom_utils_find_form_auth_elements() is great, but it only returns
 * something useful if it can pair a username node with a password node. This
 * function says whether the form has a password node or not, even if Epiphany
 * isn't smart enough to match it to a username node.
 *
 * Ideally we'd also detect credit card data or other sensitive stuff, but
 * there's no standard way to do so, so don't try.
 */
gboolean
ephy_web_dom_utils_form_contains_sensitive_element (WebKitDOMHTMLFormElement *form)
{
  WebKitDOMHTMLCollection *elements;
  guint i, n_elements;
  gboolean found_auth_element = FALSE;

  elements = webkit_dom_html_form_element_get_elements (form);
  n_elements = webkit_dom_html_collection_get_length (elements);

  for (i = 0; i < n_elements && !found_auth_element; i++) {
    WebKitDOMNode *element;
    char *element_type;

    element = webkit_dom_html_collection_item (elements, i);
    if (!WEBKIT_DOM_IS_HTML_INPUT_ELEMENT (element))
      continue;

    g_object_get (element, "type", &element_type, NULL);

    if (g_strcmp0 (element_type, "password") == 0 ||
        g_strcmp0 (element_type, "adminpw") == 0) {
      found_auth_element = TRUE;
    }

    g_free (element_type);
  }

  g_object_unref (elements);

  return found_auth_element;
}

/**
 * ephy_web_dom_utils_get_absolute_position_for_element:
 * @element: the #WebKitDOMElement.
 * @x: return address for the x coordinate.
 * @y: return address for the y coordinate.
 *
 * Obtains the coordinate for the top-left of the #WebKitDOMElement, relative
 * to the origin of the page.
 **/
void
ephy_web_dom_utils_get_absolute_position_for_element (WebKitDOMElement *element,
                                                      double           *x,
                                                      double           *y)
{
  WebKitDOMElement *parent;
  double offset_top, offset_left;
  double parent_x, parent_y;

  offset_top = webkit_dom_element_get_offset_top (element);
  offset_left = webkit_dom_element_get_offset_left (element);
  parent = webkit_dom_element_get_offset_parent (element);

  *x = offset_left;
  *y = offset_top;

  if (!parent)
    return;

  /* If there's a parent, we keep going. */
  ephy_web_dom_utils_get_absolute_position_for_element (parent, &parent_x, &parent_y);

  *x += parent_x;
  *y += parent_y;
}

/**
 * ephy_web_dom_utils_get_absolute_bottom_for_element:
 * @element: the #WebKitDOMElement.
 * @x: return address for the x coordinate.
 * @y: return address for the y coordinate.
 *
 * Obtains the coordinate for the bottom-left of the #WebKitDOMElement, relative
 * to the origin of the page.
 **/
void
ephy_web_dom_utils_get_absolute_bottom_for_element (WebKitDOMElement *element,
                                                    double           *x,
                                                    double           *y)
{
  double offset_height;

  ephy_web_dom_utils_get_absolute_position_for_element (element, x, y);

  offset_height = webkit_dom_element_get_offset_height (element);

  *y += offset_height;
}

/**
 * ephy_web_dom_utils_get_selection_as_string:
 * @selection: the #WebKitDOMDOMSelection.
 *
 * Gets the contents of the selection as a string.
 *
 * Returns: a newly allocated string with the selection or %NULL.
 **/
char *
ephy_web_dom_utils_get_selection_as_string (WebKitDOMDOMSelection *selection)
{
  char *string;
  WebKitDOMRange *range = webkit_dom_dom_selection_get_range_at (selection, 0, NULL);
  if (!range)
    return NULL;

  string = webkit_dom_range_to_string (range, NULL);
  g_object_unref (range);

  return string;
}

#pragma GCC diagnostic pop
