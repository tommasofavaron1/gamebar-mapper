using System;
using System.IO;
using System.Runtime.Serialization.Json;
using System.Threading.Tasks;
using WidgetSampleCS.Models;
using Windows.Storage;

namespace WidgetSampleCS.Services
{
    public sealed class BackendStatusStore
    {
        public async Task<BackendState> LoadAsync()
        {
            try
            {
                var file = await ApplicationData.Current.LocalFolder.GetFileAsync("backend-status.json");
                using (var stream = await file.OpenStreamForReadAsync())
                {
                    var serializer = new DataContractJsonSerializer(typeof(BackendState));
                    return serializer.ReadObject(stream) as BackendState;
                }
            }
            catch (FileNotFoundException)
            {
                return null;
            }
            catch (IOException)
            {
                return null;
            }
            catch (System.Runtime.Serialization.SerializationException)
            {
                return null;
            }
        }
    }
}