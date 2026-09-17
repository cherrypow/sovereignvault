#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Open at a fixed proportion of the screen's work area (not a fixed
  // pixel size) so the window reads the same relative to the desktop
  // on a small laptop display as on a large monitor, centered.
  //
  // The values computed here are physical pixels; Win32Window::Create
  // scales whatever logical size it's given back up by the target
  // monitor's DPI, so the system DPI is divided out first to land on
  // the intended physical size regardless of scaling.
  RECT work_area;
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  HDC screen_dc = ::GetDC(nullptr);
  double scale = ::GetDeviceCaps(screen_dc, LOGPIXELSX) / 96.0;
  ::ReleaseDC(nullptr, screen_dc);

  int work_w = work_area.right - work_area.left;
  int work_h = work_area.bottom - work_area.top;
  int phys_w = static_cast<int>(work_w * 0.66);
  int phys_h = static_cast<int>(work_h * 0.80);
  int phys_x = work_area.left + (work_w - phys_w) / 2;
  int phys_y = work_area.top + (work_h - phys_h) / 2;

  FlutterWindow window(project);
  Win32Window::Point origin(static_cast<int>(phys_x / scale), static_cast<int>(phys_y / scale));
  Win32Window::Size size(static_cast<int>(phys_w / scale), static_cast<int>(phys_h / scale));
  if (!window.Create(L"Sovereign Vault X", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
