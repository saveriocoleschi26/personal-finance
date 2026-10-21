//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import file_picker
import file_selector_macos
import icloud_storage
import local_auth_darwin
import package_info_plus
import share_plus
import sqflite_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  IcloudStoragePlugin.register(with: registry.registrar(forPlugin: "IcloudStoragePlugin"))
  LocalAuthPlugin.register(with: registry.registrar(forPlugin: "LocalAuthPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  SharePlusMacosPlugin.register(with: registry.registrar(forPlugin: "SharePlusMacosPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
}
