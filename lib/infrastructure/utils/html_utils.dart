import 'package:html/dom.dart' as dom;

/// Utilidades para manipular y extraer datos del DOM de HTML
/// Similar a DOMUtils del código TypeScript
class HtmlUtils {
  /// Encuentra el primer elemento que coincida con el selector CSS
  static dom.Element? findElement(dom.Node parent, String selector) {
    if (parent is dom.Element) {
      return parent.querySelector(selector);
    } else if (parent is dom.Document) {
      return parent.querySelector(selector);
    }
    return null;
  }

  /// Encuentra todos los elementos que coincidan con el selector CSS
  static List<dom.Element> findElements(dom.Node parent, String selector) {
    if (parent is dom.Element) {
      return parent.querySelectorAll(selector);
    } else if (parent is dom.Document) {
      return parent.querySelectorAll(selector);
    }
    return [];
  }

  /// Obtiene el contenido de texto de un elemento
  static String getTextContent(dom.Element? element) {
    if (element == null) return '';
    return element.text.trim();
  }

  /// Encuentra elementos por nombre de etiqueta
  static List<dom.Element> getElementsByTagName(dom.Node parent, String tagName) {
    if (parent is dom.Element) {
      return parent.getElementsByTagName(tagName);
    } else if (parent is dom.Document) {
      return parent.getElementsByTagName(tagName);
    }
    return [];
  }

  /// Encuentra un elemento por clase CSS
  static dom.Element? findElementByClass(dom.Node parent, String className) {
    return findElement(parent, '.$className');
  }

  /// Encuentra elementos por clase CSS
  static List<dom.Element> findElementsByClass(dom.Node parent, String className) {
    return findElements(parent, '.$className');
  }

  /// Extrae el valor de un atributo de un elemento
  static String getAttribute(dom.Element? element, String attributeName) {
    return element?.attributes[attributeName] ?? '';
  }

  /// Verifica si un elemento tiene una clase específica
  static bool hasClass(dom.Element? element, String className) {
    if (element == null) return false;
    final classes = element.attributes['class']?.split(' ') ?? [];
    return classes.contains(className);
  }
}