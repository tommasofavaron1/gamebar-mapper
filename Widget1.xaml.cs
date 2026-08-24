using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using WidgetSampleCS.Models;
using WidgetSampleCS.Services;
using Windows.Gaming.Input;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Navigation;

namespace WidgetSampleCS
{
    public sealed partial class Widget1 : Page
    {
        private readonly DispatcherTimer inputTimer;
        private readonly ProfileStore profileStore = new ProfileStore();
        private readonly BackendStatusStore backendStatusStore = new BackendStatusStore();
        private DateTime nextBackendRefresh = DateTime.MinValue;
        private bool isInitializing;
        private bool statusRefreshInProgress;

        public MappingProfile Profile { get; private set; } = MappingProfile.CreateDefault();
        public IReadOnlyList<string> ControllerOptions { get; } = new[]
        {
            "Controller 1", "Controller 2", "Controller 3", "Controller 4"
        };

        public Widget1()
        {
            InitializeComponent();
            inputTimer = new DispatcherTimer { Interval = System.TimeSpan.FromMilliseconds(50) };
            inputTimer.Tick += InputTimer_Tick;
            Loaded += Widget1_Loaded;
            Unloaded += Widget1_Unloaded;
        }

        private async void Widget1_Loaded(object sender, RoutedEventArgs e)
        {
            Profile = await profileStore.LoadAsync();
            Bindings.Update();
            isInitializing = true;
            Profile.SelectedControllerIndex = Math.Max(0, Math.Min(3, Profile.SelectedControllerIndex));
            ControllerSelector.SelectedIndex = Profile.SelectedControllerIndex;
            RemapToggle.IsOn = Profile.Enabled;
            isInitializing = false;
            inputTimer.Start();
            await RefreshBackendStatusAsync();
        }

        private void Widget1_Unloaded(object sender, RoutedEventArgs e)
        {
            inputTimer.Stop();
        }

        private void InputTimer_Tick(object sender, object e)
        {
            var selectedIndex = Profile.SelectedControllerIndex;
            var gamepad = Gamepad.Gamepads.ElementAtOrDefault(selectedIndex);
            if (gamepad == null)
            {
                ControllerStatus.Text = $"Controller {selectedIndex + 1} non rilevato";
                PressedButtons.Text = "Nessun tasto premuto";
                return;
            }

            ControllerStatus.Text = $"Controller {selectedIndex + 1} connesso";
            var reading = gamepad.GetCurrentReading();
            var pressed = Profile.Mappings
                .Where(mapping => mapping.IsPressed(reading))
                .Select(mapping => PreviewToggle.IsOn ? mapping.Target : mapping.Source)
                .Where(button => button != MappingEntry.DisabledTarget)
                .Distinct()
                .ToArray();

            PressedButtons.Text = pressed.Length == 0
                ? "Nessun tasto premuto"
                : string.Join("  +  ", pressed);

            if (DateTime.UtcNow >= nextBackendRefresh)
            {
                nextBackendRefresh = DateTime.UtcNow.AddSeconds(1);
                _ = RefreshBackendStatusAsync();
            }
        }

        private void PreviewToggle_Toggled(object sender, RoutedEventArgs e)
        {
        }

        private async void ControllerSelector_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (isInitializing || ControllerSelector.SelectedIndex < 0)
            {
                return;
            }

            Profile.SelectedControllerIndex = ControllerSelector.SelectedIndex;
            await profileStore.SaveAsync(Profile);
            BackendStatus.Text = $"Controller {Profile.SelectedControllerIndex + 1} selezionato";
        }

        private async void RemapToggle_Toggled(object sender, RoutedEventArgs e)
        {
            if (isInitializing)
            {
                return;
            }

            Profile.Enabled = RemapToggle.IsOn;
            await profileStore.SaveAsync(Profile);
            BackendStatus.Text = Profile.Enabled
                ? "Avvio controller virtuale..."
                : "Rimappatura disattivata";
        }

        private async void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            await profileStore.SaveAsync(Profile);
            BackendStatus.Text = Profile.Enabled
                ? "Profilo salvato: applicazione in corso"
                : "Profilo salvato localmente";
        }

        private async Task RefreshBackendStatusAsync()
        {
            if (statusRefreshInProgress)
            {
                return;
            }

            statusRefreshInProgress = true;
            try
            {
                var state = await backendStatusStore.LoadAsync();
                if (state != null && !string.IsNullOrWhiteSpace(state.Message))
                {
                    BackendStatus.Text = state.Message;
                }
                else if (Profile.Enabled)
                {
                    BackendStatus.Text = "Backend non avviato";
                }
            }
            finally
            {
                statusRefreshInProgress = false;
            }
        }
    }
}
