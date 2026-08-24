using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.Serialization;
using Windows.Gaming.Input;

namespace WidgetSampleCS.Models
{
    [DataContract]
    public sealed class MappingProfile
    {
        [DataMember]
        public string Name { get; set; } = "Predefinito";

        [DataMember]
        public bool Enabled { get; set; }

        [DataMember]
        public int SelectedControllerIndex { get; set; }

        [DataMember]
        public ObservableCollection<MappingEntry> Mappings { get; set; } = new ObservableCollection<MappingEntry>();

        public static MappingProfile CreateDefault()
        {
            var profile = new MappingProfile();
            foreach (var button in MappingEntry.SupportedButtons)
            {
                profile.Mappings.Add(new MappingEntry { Source = button, Target = button });
            }

            return profile;
        }
    }

    [DataContract]
    public sealed class MappingEntry : INotifyPropertyChanged
    {
        public const string DisabledTarget = "Disabilitato";

        public static readonly IReadOnlyList<string> SupportedButtons = Array.AsReadOnly(new[]
        {
            "A", "B", "X", "Y", "DPadUp", "DPadDown", "DPadLeft", "DPadRight",
            "LeftShoulder", "RightShoulder", "LeftThumbstick", "RightThumbstick", "Menu", "View"
        });

        private string target;

        [DataMember]
        public string Source { get; set; }

        [DataMember]
        public string Target
        {
            get => target;
            set
            {
                if (target == value)
                {
                    return;
                }

                target = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Target)));
            }
        }

        public IReadOnlyList<string> TargetOptions
        {
            get
            {
                var targets = new List<string>(SupportedButtons) { DisabledTarget };
                return targets;
            }
        }

        public event PropertyChangedEventHandler PropertyChanged;

        public bool IsPressed(GamepadButtons buttons)
        {
            return Enum.TryParse(Source, out GamepadButtons sourceButton)
                && (buttons & sourceButton) == sourceButton;
        }
    }
}